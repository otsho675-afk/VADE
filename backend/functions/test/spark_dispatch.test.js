import {test} from 'node:test';
import assert from 'node:assert/strict';
import {dispatchSparkPush} from '../dispatch_push_spark.js';
import {NO_FUTURE_ALERT} from '../push_reminders.js';

const now = Date.UTC(2026, 9, 14, 12, 0, 0);
function fakeDb() {
  const ref = {value: {
    uid: 'demo',
    enabled: true,
    fcmToken: 'example_registration_token_that_is_long_enough',
    nextDueAtMillis: now - 2000,
    reminders: [{id: 31, atMillis: now - 2000,
      title: 'Hatırlatma', body: 'Ödeme durumunuzu kontrol edin.'}],
  }};
  const doc = {id: 'device-1', ref};
  const query = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    startAfter: () => query,
    async get() {
      const due = ref.value.nextDueAtMillis <= now;
      return {empty: !due, size: due ? 1 : 0, docs: due ? [doc] : []};
    },
  };
  const db = {
    collection: () => query,
    async runTransaction(fn) {
      return fn({
        get: async current => ({exists:true, data: () => ({...current.value})}),
        update(current, patch) { current.value = {...current.value, ...patch}; },
      });
    },
  };
  return {db, ref};
}

test('free dispatcher sends a due FCM alert and prevents duplicate dispatch', async () => {
  const {db, ref} = fakeDb();
  const messages = [];
  const messaging = {send: async payload => {messages.push(payload);}};
  const logger = {info:()=>{}, error:()=>{}};
  const first = await dispatchSparkPush({db, messaging, now, logger});
  const second = await dispatchSparkPush({db, messaging, now, logger});
  assert.equal(first.sent, 1);
  assert.equal(second.sent, 0);
  assert.equal(ref.value.nextDueAtMillis, NO_FUTURE_ALERT);
  assert.equal(messages[0].data.kind, 'vade_reminder');
  assert.equal(messages[0].android.notification.channelId, 'vadesi_risk');
});

test('transient FCM failure restores an alert for retry without cost', async () => {
  const {db, ref} = fakeDb();
  const messaging = {send: async () => {throw Object.assign(new Error('offline'), {
    code: 'messaging/internal-error',
  });}};
  const logger = {info:()=>{}, error:()=>{}};
  const result = await dispatchSparkPush({db, messaging, now, logger});
  assert.equal(result.failed, 1);
  assert.equal(ref.value.nextDueAtMillis, now - 2000);
  assert.deepEqual(ref.value.delivered, {});
});

test('invalid FCM token disables the registration until it is refreshed', async () => {
  const {db, ref} = fakeDb();
  const messaging = {send: async () => {throw Object.assign(new Error('expired'), {
    code: 'messaging/registration-token-not-registered',
  });}};
  const logger = {info:()=>{}, error:()=>{}};
  await dispatchSparkPush({db, messaging, now, logger});
  assert.equal(ref.value.enabled, false);
  assert.equal(ref.value.nextDueAtMillis, NO_FUTURE_ALERT);
});
