import {test} from 'node:test';
import {strict as assert} from 'node:assert';
import {dueNotifications} from '../push_reminders.js';

const now = Date.UTC(2026, 9, 14, 9, 5);
const device = {enabled: true, fcmToken: 'valid_mock_notification_registration_token',
  reminders: [{id: 12, atMillis: now - 5000,
    title: 'Vade bugün', body: 'Ödemeni kontrol et'}]};

test('due notifications only qualify after the selected time', () => {
  assert.equal(dueNotifications(device, now).length, 1);
  assert.equal(dueNotifications(device, now - 6000).length, 0);
});

test('disabled push and delivered reminders do not send again', () => {
  assert.equal(dueNotifications({...device, enabled: false}, now).length, 0);
  assert.equal(dueNotifications({...device, delivered: {
    [`12_${now - 5000}`]: now,
  }}, now).length, 0);
});

test('malformed and stale reminders are not sent', () => {
  assert.equal(dueNotifications({...device, reminders: [
    {...device.reminders[0], atMillis: now - 25 * 60 * 60 * 1000},
  ]}, now).length, 0);
  assert.equal(dueNotifications({...device, reminders: [
    {...device.reminders[0], title: ''},
  ]}, now).length, 0);
});
