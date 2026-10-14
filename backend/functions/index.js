import {createHash} from 'node:crypto';
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {defineSecret, defineString} from 'firebase-functions/params';
import {google} from 'googleapis';
import {AppStoreServerAPIClient, SignedDataVerifier, Environment} from '@apple/app-store-server-library';
import {PRODUCTS, googleEntitlement, appleEntitlement} from './receipts.js';

initializeApp();
const db = getFirestore();
const region = 'europe-west1';
const androidPackage = defineString('ANDROID_PACKAGE', {default: 'com.vadesi.vadesi'});
const appleBundle = defineString('APPLE_BUNDLE_ID', {default: 'com.vadesi.vadesi'});
const appleAppId = defineString('APPLE_APP_ID', {default: ''});
const appleIssuer = defineString('APPLE_ISSUER_ID', {default: ''});
const appleKeyId = defineString('APPLE_KEY_ID', {default: ''});
const appleEnvironment = defineString('APPLE_ENVIRONMENT', {default: 'Production'});
const appleKey = defineSecret('APPLE_PRIVATE_KEY');
const appleRoots = defineSecret('APPLE_ROOT_CERTIFICATES_BASE64_JSON');
const oneSignalKey = defineSecret('ONESIGNAL_REST_API_KEY');
const oneSignalAppId = defineString('ONESIGNAL_APP_ID', {default: ''});
const hash = value => createHash('sha256').update(value).digest('hex');
const options = {region, maxInstances: 5, secrets: [appleKey, appleRoots]};
const publisher = () => google.androidpublisher({version: 'v3',
  auth: new google.auth.GoogleAuth({scopes: ['https://www.googleapis.com/auth/androidpublisher']})});

function accountToken(uid) {
  const h = hash(uid);
  return h.slice(0,8) + '-' + h.slice(8,12) + '-4' + h.slice(13,16) + '-a' + h.slice(17,20) + '-' + h.slice(20,32);
}
function requireUser(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}
function appleClients() {
  const environment = appleEnvironment.value() === 'Sandbox' ? Environment.SANDBOX : Environment.PRODUCTION;
  const roots = JSON.parse(appleRoots.value()).map(value => Buffer.from(value, 'base64'));
  return {
    client: new AppStoreServerAPIClient(appleKey.value(), appleKeyId.value(),
      appleIssuer.value(), appleBundle.value(), environment),
    verifier: new SignedDataVerifier(roots, true, environment, appleBundle.value(),
      environment === Environment.PRODUCTION ? Number(appleAppId.value()) : undefined)
  };
}

async function verify(store, productId, token, transactionId, uid) {
  if (store === 'google') {
    const {data} = await publisher().purchases.subscriptionsv2.get({
      packageName: androidPackage.value(), token
    });
    if (data.externalAccountIdentifiers?.obfuscatedExternalAccountId !== accountToken(uid)) {
      throw new Error('Account mismatch');
    }
    return {...googleEntitlement(data, productId), linkedToken: data.linkedPurchaseToken ?? null};
  }
  if (store === 'apple') {
    const {client, verifier} = appleClients();
    const response = await client.getTransactionInfo(transactionId);
    const decoded = await verifier.verifyAndDecodeTransaction(response.signedTransactionInfo);
    if (decoded.appAccountToken?.toLowerCase() !== accountToken(uid)) throw new Error('Account mismatch');
    return appleEntitlement(decoded, productId, appleBundle.value());
  }
  throw new Error('Unknown store');
}

async function recompute(uid) {
  if (uid.startsWith('deleted:')) return;
  const receipts = await db.collection('_receipts').where('uid', '==', uid).get();
  const until = receipts.docs.reduce((max, doc) => Math.max(max, doc.data().premiumUntilMillis || 0), 0);
  await db.doc('entitlements/' + uid).set({
    premiumUntilMillis: until, updatedAt: FieldValue.serverTimestamp()
  });
}

export const verifyPurchase = onCall(options, async request => {
  const uid = requireUser(request);
  const {store, productId, verificationData, transactionId} = request.data ?? {};
  if (!PRODUCTS.has(productId) || !['google','apple'].includes(store) ||
      (store === 'google' && (typeof verificationData !== 'string' || verificationData.length < 1 || verificationData.length > 12000)) ||
      (store === 'apple' && (typeof transactionId !== 'string' || !/^\d{1,40}$/.test(transactionId)))) {
    throw new HttpsError('invalid-argument', 'Geçersiz ürün.');
  }
  let verified;
  try { verified = await verify(store, productId, verificationData, transactionId, uid); }
  catch { throw new HttpsError('failed-precondition', 'Mağaza satın almayı doğrulamadı.'); }
  const identity = store === 'google' ? verificationData : verified.originalId;
  const ref = db.doc('_receipts/' + hash(store + ':' + identity));
  await db.runTransaction(async tx => {
    const previous = await tx.get(ref);
    if (previous.exists && previous.data().uid !== uid) {
      throw new HttpsError('already-exists', 'Satın alma başka bir hesaba bağlı.');
    }
    if (verified.linkedToken) {
      const linked = await tx.get(db.doc('_receipts/' + hash('google:' + verified.linkedToken)));
      if (linked.exists && linked.data().uid !== uid) {
        throw new HttpsError('already-exists', 'Abonelik başka bir hesaba bağlı.');
      }
    }
    tx.set(ref, {uid, store, productId, token: store === 'google' ? verificationData : null,
      transactionId: store === 'apple' ? verified.originalId : null,
      premiumUntilMillis: verified.premiumUntilMillis, updatedAt: FieldValue.serverTimestamp()});
    tx.set(db.doc('orders/' + ref.id), {uid, store, productId,
      premiumUntilMillis: verified.premiumUntilMillis, verifiedAt: FieldValue.serverTimestamp()});
  });
  if (store === 'google' && verified.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
    await publisher().purchases.subscriptions.acknowledge({
      packageName: androidPackage.value(), subscriptionId: productId, token: verificationData, requestBody: {}
    });
  }
  await recompute(uid);
  return {premiumUntilMillis: verified.premiumUntilMillis};
});

// Provider failures preserve the last verified expiry and never extend it.
export const reconcileSubscriptions = onSchedule({...options, schedule: 'every 6 hours',
  timeoutSeconds: 540}, async () => {
  let cursor;
  do {
    let query = db.collection('_receipts').orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      const receipt = doc.data();
      if (receipt.uid.startsWith('deleted:')) continue;
      try {
        let until = 0;
        if (receipt.store === 'google') {
          const {data} = await publisher().purchases.subscriptionsv2.get({
            packageName: androidPackage.value(), token: receipt.token});
          try { until = googleEntitlement(data, receipt.productId).premiumUntilMillis; } catch {}
        } else {
          const {client, verifier} = appleClients();
          const response = await client.getAllSubscriptionStatuses(receipt.transactionId);
          for (const group of response.data ?? []) {
            for (const last of group.lastTransactions ?? []) {
              if (![1,4].includes(last.status)) continue;
              const transaction = await verifier.verifyAndDecodeTransaction(last.signedTransactionInfo);
              try { until = Math.max(until, appleEntitlement(transaction, transaction.productId,
                appleBundle.value()).premiumUntilMillis); } catch {}
            }
          }
        }
        await doc.ref.update({premiumUntilMillis: until, updatedAt: FieldValue.serverTimestamp()});
        await db.doc('orders/' + doc.id).update({premiumUntilMillis: until});
        await recompute(receipt.uid);
      } catch (error) { console.warn('Subscription reconciliation failed', doc.id, error.code ?? 'provider-error'); }
    }
    cursor = page.docs.length === 100 ? page.docs.at(-1) : null;
  } while (cursor);
});

export const sendAnnouncement = onCall({region, maxInstances: 2, secrets: [oneSignalKey]}, async request => {
  const uid = requireUser(request);
  if (request.auth.token.admin !== true) throw new HttpsError('permission-denied', 'Yönetici yetkisi gerekli.');
  const {title, body} = request.data ?? {};
  if (typeof title !== 'string' || title.length < 1 || title.length > 80 ||
      typeof body !== 'string' || body.length < 1 || body.length > 500) {
    throw new HttpsError('invalid-argument', 'Başlık ve mesaj gerekli.');
  }
  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: 'Key ' + oneSignalKey.value()},
    body: JSON.stringify({app_id: oneSignalAppId.value(), target_channel: 'push',
      included_segments: ['Subscribed Users'], headings: {en: title, tr: title}, contents: {en: body, tr: body}})
  });
  if (!response.ok) throw new HttpsError('unavailable', 'Bildirim sağlayıcısı isteği kabul etmedi.');
  const result = await response.json();
  if (!result.id) throw new HttpsError('failed-precondition', 'Ulaşılabilir abone bulunamadı.');
  await db.collection('audit').add({uid, action: 'announcement', title, providerId: result.id,
    createdAt: FieldValue.serverTimestamp()});
  return {id: result.id};
});

export const deleteMyAccount = onCall({region, maxInstances: 3}, async request => {
  const uid = requireUser(request);
  if (Date.now() / 1000 - (request.auth.token.auth_time ?? 0) > 300) {
    throw new HttpsError('unauthenticated', 'Silmek için tekrar giriş yapın.');
  }
  await db.recursiveDelete(db.doc('users/' + uid));
  const devices = await db.collection('push_devices').where('uid', '==', uid).get();
  for (const device of devices.docs) await device.ref.delete();
  await getDatabase().ref('presence/' + uid).remove();
  await db.doc('entitlements/' + uid).delete();
  const receipts = await db.collection('_receipts').where('uid', '==', uid).get();
  for (const receipt of receipts.docs) {
    await receipt.ref.set({uid: 'deleted:' + hash(uid), store: receipt.data().store,
      premiumUntilMillis: 0, deletedAt: FieldValue.serverTimestamp()});
    await db.doc('orders/' + receipt.id).delete();
  }
  await getAuth().deleteUser(uid);
  return {deleted: true};
});
