import test from 'node:test';
import assert from 'node:assert/strict';
import {googleEntitlement, appleEntitlement} from '../receipts.js';
const product = 'vadesi_premium_monthly';
const now = 1700000000000;
const google = {subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
  lineItems: [{productId: product, expiryTime: new Date(now + 10000).toISOString()}]};
test('Google validates product, expiry and state', () => {
  assert.equal(googleEntitlement(google, product, now).premiumUntilMillis, now + 10000);
  assert.throws(() => googleEntitlement(google, 'wrong', now));
  assert.throws(() => googleEntitlement(google, product, now + 20000));
  assert.throws(() => googleEntitlement({...google, subscriptionState: 'SUBSCRIPTION_STATE_ON_HOLD'}, product, now));
  assert.equal(googleEntitlement({...google, subscriptionState: 'SUBSCRIPTION_STATE_CANCELED'}, product, now).premiumUntilMillis, now + 10000);
});
test('Apple rejects revoked, expired, wrong bundle and mismatched products', () => {
  const value = {productId: product, bundleId: 'com.vadesi.vadesi', expiresDate: now + 10000, originalTransactionId: '100'};
  assert.equal(appleEntitlement(value, product, value.bundleId, now).originalId, '100');
  assert.throws(() => appleEntitlement({...value, revocationDate: now}, product, value.bundleId, now));
  assert.throws(() => appleEntitlement(value, product, 'other', now));
  assert.throws(() => appleEntitlement(value, 'vadesi_premium_yearly', value.bundleId, now));
  assert.throws(() => appleEntitlement(value, product, value.bundleId, now + 20000));
});
