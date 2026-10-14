import {readFileSync} from 'node:fs';
import {before, after, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, serverTimestamp} from 'firebase/firestore';
import {ref, set, get} from 'firebase/database';
let env;
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-vadesi',
    firestore:{rules:readFileSync('../firestore.rules','utf8'),host:'127.0.0.1',port:8081},
    database:{rules:readFileSync('../database.rules.json','utf8'),host:'127.0.0.1',port:9000}});
});
beforeEach(async () => { await env.clearFirestore(); await env.clearDatabase(); });
after(async () => { await env?.cleanup(); });
test('profile ownership, admin read and blocked entitlement writes', async () => {
  const alice = env.authenticatedContext('alice',{email:'alice@example.com'}).firestore();
  const bob = env.authenticatedContext('bob',{email:'bob@example.com'}).firestore();
  const admin = env.authenticatedContext('admin',{admin:true}).firestore();
  await assertSucceeds(setDoc(doc(alice,'users/alice'),{
    email:'alice@example.com',displayName:'Alice',lastSeenAt:serverTimestamp()}));
  await assertFails(getDoc(doc(bob,'users/alice')));
  await assertSucceeds(getDoc(doc(admin,'users/alice')));
  await assertFails(setDoc(doc(alice,'entitlements/alice'),{premiumUntilMillis:Date.now()+999999}));
  await assertFails(setDoc(doc(alice,'users/alice'),{
    email:'alice@example.com',displayName:'Alice',lastSeenAt:serverTimestamp(),admin:true}));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/alice')));
});
test('backup requires active server entitlement; expired users retain read access', async () => {
  const alice = env.authenticatedContext('alice',{email:'alice@example.com'}).firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const path = 'users/alice/private/backup';
  const backup = () => ({payload:'{}',updatedAt:serverTimestamp()});
  await assertFails(setDoc(doc(alice,path),backup()));
  await env.withSecurityRulesDisabled(async context =>
    setDoc(doc(context.firestore(),'entitlements/alice'),{premiumUntilMillis:Date.now()+60000}));
  await assertSucceeds(setDoc(doc(alice,path),backup()));
  await assertFails(getDoc(doc(bob,path)));
  await assertFails(getDoc(doc(env.authenticatedContext('admin',{admin:true}).firestore(),path)));
  await env.withSecurityRulesDisabled(async context =>
    setDoc(doc(context.firestore(),'entitlements/alice'),{premiumUntilMillis:0}));
  await assertSucceeds(getDoc(doc(alice,path)));
  await assertFails(setDoc(doc(alice,path),backup()));
});
test('presence writes are private to owner and aggregate reads require admin', async () => {
  const alice = env.authenticatedContext('alice').database();
  const bob = env.authenticatedContext('bob').database();
  const admin = env.authenticatedContext('admin',{admin:true}).database();
  await assertSucceeds(set(ref(alice,'presence/alice/connections/a'),true));
  await assertFails(set(ref(bob,'presence/alice/connections/b'),true));
  await assertFails(get(ref(bob,'presence/alice')));
  await assertFails(get(ref(alice,'presence')));
  await assertSucceeds(get(ref(admin,'presence')));
  await assertFails(set(ref(alice,'presence/alice/fake'),true));
});

test('push tokens are private and server delivery markers cannot be reset by clients', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const path = 'push_devices/alice_abcdefghijklmnopqrstuv';
  const push = () => ({
    uid:'alice', fcmToken:'valid_long_test_token_0123456789', platform:'android',
    enabled:true, reminders:[], updatedAt:serverTimestamp(),
  });
  await assertSucceeds(setDoc(doc(alice,path),push()));
  await assertFails(getDoc(doc(bob,path)));
  await assertFails(setDoc(doc(bob,path),{...push(), uid:'bob'}));
  await assertSucceeds(setDoc(doc(alice,path),{enabled:false, updatedAt:serverTimestamp()}, {merge:true}));
  await env.withSecurityRulesDisabled(async context =>
    setDoc(doc(context.firestore(),path),{delivered:{reminder_1:Date.now()}}, {merge:true}));
  await assertFails(setDoc(doc(alice,path),{delivered:{}}, {merge:true}));
});
