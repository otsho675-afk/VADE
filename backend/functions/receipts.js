export const PRODUCTS = new Set(['vadesi_premium_monthly', 'vadesi_premium_yearly']);

export function googleEntitlement(data, expectedProduct, now = Date.now()) {
  if (!PRODUCTS.has(expectedProduct)) throw new Error('Unknown product');
  const line = data.lineItems?.find(item => item.productId === expectedProduct);
  const until = Date.parse(line?.expiryTime ?? '');
  const states = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_CANCELED'];
  if (!states.includes(data.subscriptionState) || !Number.isFinite(until) || until <= now) {
    throw new Error('Subscription is not active');
  }
  return {premiumUntilMillis: until, productId: expectedProduct,
    originalId: data.latestOrderId, acknowledgementState: data.acknowledgementState};
}

export function appleEntitlement(transaction, expectedProduct, bundleId, now = Date.now()) {
  if (!PRODUCTS.has(expectedProduct) || transaction.productId !== expectedProduct ||
      transaction.bundleId !== bundleId || transaction.revocationDate ||
      !Number.isFinite(transaction.expiresDate) || transaction.expiresDate <= now ||
      !transaction.originalTransactionId) throw new Error('Subscription is not active');
  return {premiumUntilMillis: transaction.expiresDate, productId: expectedProduct,
    originalId: String(transaction.originalTransactionId)};
}
