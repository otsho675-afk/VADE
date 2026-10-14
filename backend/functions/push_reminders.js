/** Validate user-owned schedules before a server-side push is sent. */
export function dueNotifications(device, now) {
  if (!device || device.enabled !== true || typeof device.fcmToken !== 'string' ||
      device.fcmToken.length < 20 || !Array.isArray(device.reminders)) return [];
  const delivered = device.delivered ?? {};
  return device.reminders.slice(0, 60).filter(r =>
    r && Number.isSafeInteger(r.id) && Number.isSafeInteger(r.atMillis) &&
    r.atMillis <= now && r.atMillis > now - 86400000 &&
    typeof r.title === 'string' && r.title.trim().length > 0 && r.title.length <= 80 &&
    typeof r.body === 'string' && r.body.length <= 300 &&
    !delivered[`${r.id}_${r.atMillis}`]
  ).slice(0, 20).map(r => ({...r, key: `${r.id}_${r.atMillis}`}));
}

/** Upper bound used for a device with no remaining alert. Query excludes it. */
export const NO_FUTURE_ALERT = 253402300799000;

export function nextDueAtMillis(device, now) {
  if (device?.enabled !== true || !Array.isArray(device?.reminders)) {
    return NO_FUTURE_ALERT;
  }
  const delivered = device.delivered ?? {};
  let nearest = NO_FUTURE_ALERT;
  for (const reminder of device.reminders.slice(0, 60)) {
    if (!reminder || !Number.isSafeInteger(reminder.id) ||
        !Number.isSafeInteger(reminder.atMillis) ||
        reminder.atMillis <= now - 86400000 ||
        reminder.atMillis > NO_FUTURE_ALERT ||
        delivered[`${reminder.id}_${reminder.atMillis}`]) continue;
    nearest = Math.min(nearest, reminder.atMillis);
  }
  return nearest;
}
