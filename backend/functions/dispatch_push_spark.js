import {initializeApp, cert, getApps} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {dueNotifications, nextDueAtMillis, NO_FUTURE_ALERT} from './push_reminders.js';

const PROJECT_ID = 'vade-b46fb';
const INVALID_TOKENS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);
const BATCH_SIZE = 100;
const MAX_DOCS_PER_RUN = 400;

function compactDelivered(delivered, now) {
  return Object.fromEntries(
    Object.entries(delivered ?? {})
      .filter(([, time]) => Number.isSafeInteger(time) && time >= now - 30 * 86400000)
      .slice(-120),
  );
}

async function reserveDue(ref, db, now) {
  return db.runTransaction(async transaction => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return [];
    const data = snapshot.data();
    if (data.enabled !== true) {
      transaction.update(ref, {nextDueAtMillis: NO_FUTURE_ALERT});
      return [];
    }
    const due = dueNotifications(data, now);
    const delivered = compactDelivered(data.delivered, now);
    for (const reminder of due) delivered[reminder.key] = now;
    transaction.update(ref, {
      delivered,
      nextDueAtMillis: nextDueAtMillis({...data, delivered}, now),
    });
    return due.map(reminder => ({...reminder, token: data.fcmToken}));
  });
}

async function resolveDeliveryError(ref, db, reminder, now, error) {
  await db.runTransaction(async transaction => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return;
    const data = snapshot.data();
    if (INVALID_TOKENS.has(error.code)) {
      transaction.update(ref, {
        enabled: false,
        nextDueAtMillis: NO_FUTURE_ALERT,
      });
      return;
    }
    const delivered = {...(data.delivered ?? {})};
    if (delivered[reminder.key] !== now) return; // A newer run changed it.
    delete delivered[reminder.key];
    transaction.update(ref, {
      delivered,
      nextDueAtMillis: nextDueAtMillis({...data, delivered}, now),
    });
  });
}

/** Safe, server-side-only FCM delivery. Neither device token nor financial data is logged. */
export async function dispatchSparkPush({db, messaging, now = Date.now(), logger = console}) {
  let visited = 0;
  let sent = 0;
  let failed = 0;
  let cursor;
  while (visited < MAX_DOCS_PER_RUN) {
    let query = db.collection('push_devices')
      .where('nextDueAtMillis', '<=', now)
      .orderBy('nextDueAtMillis')
      .limit(Math.min(BATCH_SIZE, MAX_DOCS_PER_RUN - visited));
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      visited++;
      try {
        const reminders = await reserveDue(doc.ref, db, now);
        for (const reminder of reminders) {
          try {
            await messaging.send({
              token: reminder.token,
              notification: {title: reminder.title, body: reminder.body},
              data: {
                kind: 'vade_reminder',
                reminderId: String(reminder.id),
              },
              android: {
                priority: 'high',
                notification: {
                  channelId: 'vadesi_risk',
                  sound: 'default',
                  tag: 'vadesi-' + reminder.id,
                },
              },
              apns: {
                headers: {'apns-priority': '10', 'apns-push-type': 'alert'},
                payload: {aps: {sound: 'default'}},
              },
            });
            sent++;
          } catch (error) {
            failed++;
            logger.error('FCM delivery failed:', error.code ?? error.message);
            await resolveDeliveryError(doc.ref, db, reminder, now, error);
          }
        }
      } catch (error) {
        failed++;
        logger.error('Push device processing failed:', error.code ?? error.message);
      }
    }
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < BATCH_SIZE) break;
  }
  logger.info(`Spark push: inspected ${visited} due devices, sent ${sent}, errors ${failed}.`);
  return {visited, sent, failed};
}

async function main() {
  const json = process.env.VADE_FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json) {
    throw new Error(
      'Configure VADE_FIREBASE_SERVICE_ACCOUNT_JSON as a GitHub Actions secret. '
      + 'Do not paste Firebase private keys in source code or the chat.',
    );
  }
  const credentials = JSON.parse(json);
  if (credentials.project_id !== PROJECT_ID || credentials.type !== 'service_account') {
    throw new Error('Wrong Firebase service account: expected vade-b46fb.');
  }
  if (!getApps().length) initializeApp({credential: cert(credentials), projectId: PROJECT_ID});
  const result = await dispatchSparkPush({db: getFirestore(), messaging: getMessaging()});
  if (result.failed > 0) process.exitCode = 1;
}

// Module may be imported from unit tests without accessing Firebase credentials.
if (process.argv[1]?.endsWith('dispatch_push_spark.js')) {
  main().catch(error => {
    console.error('Spark push failed:', error.code ?? error.message);
    process.exitCode = 1;
  });
}
