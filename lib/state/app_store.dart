import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local_database.dart';
import '../models/payment.dart';
import '../services/reminder_service.dart';

class AppStore extends ChangeNotifier {
  final LocalDatabase db;
  final ReminderService reminders;
  AppStore({LocalDatabase? database, ReminderService? reminderService})
      : db = database ?? LocalDatabase(), reminders = reminderService ?? ReminderService();
  bool _disposed = false;
  bool get supportsNotifications => reminders.supported;
  List<DueItem> items = [];
  bool loading = true;
  String? error;
  String? reminderError;
  ThemeMode themeMode = ThemeMode.system;
  bool notificationsEnabled = false;
  int notifyHour = 9;

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == prefs.getString('theme_mode'), orElse: () => ThemeMode.system);
      notificationsEnabled = supportsNotifications && (prefs.getBool('notifications_enabled') ?? false);
      notifyHour = (prefs.getInt('notify_hour') ?? 9).clamp(0, 23);
      await reminders.initialize();
      await refresh();
    } catch (e) {
      error = 'Başlatma sırasında hata oluştu: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    items = await db.allItems();
    try {
      await reminders.sync(items, enabled: notificationsEnabled, hour: notifyHour);
      reminderError = null;
    } catch (e) {
      reminderError = '$e';
    }
    notifyListeners();
  }

  Future<void> add(PlanDraft draft) async {
    await db.addPlan(draft);
    await refresh();
  }

  Future<void> edit(PaymentPlan existing, PlanDraft draft) async {
    await db.updatePlan(existing, draft);
    await refresh();
  }

  Future<void> markPaid(DueItem item) async {
    await db.pay(item);
    await refresh();
  }

  Future<void> undoPaid(DueItem item) async {
    await db.undo(item);
    await refresh();
  }

  Future<void> reschedule(DueItem item, DateTime date) async {
    await db.updateDueDate(item, date);
    await refresh();
  }

  Future<void> removePlan(int planId) async {
    await db.deletePlan(planId);
    await refresh();
  }

  Future<void> setTheme(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString('theme_mode', value.name);
  }

  Future<bool> setNotifications(bool enabled) async {
    if (enabled && !(await reminders.requestPermissions())) return false;
    notificationsEnabled = enabled;
    (await SharedPreferences.getInstance()).setBool('notifications_enabled', enabled);
    await reminders.sync(items, enabled: enabled, hour: notifyHour);
    notifyListeners();
    return true;
  }

  Future<void> setNotifyHour(int value) async {
    if (value < 0 || value > 23) throw ArgumentError.value(value, 'hour');
    notifyHour = value;
    (await SharedPreferences.getInstance()).setInt('notify_hour', value);
    await reminders.sync(items, enabled: notificationsEnabled, hour: value);
    notifyListeners();
  }

  List<DueItem> get upcoming {
    final map = <int, DueItem>{};
    for (final item in items) {
      if (item.isPaid) continue;
      map.putIfAbsent(item.planId, () => item);
    }
    final list = map.values.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  List<DueItem> get history => (items.where((e) => e.isPaid).toList()
    ..sort((a, b) => b.paidAt!.compareTo(a.paidAt!)));

  List<DueItem> planItems(int id) => items.where((e) => e.planId == id).toList()
    ..sort((a, b) => a.sequence.compareTo(b.sequence));

  int get monthOutgoing => items.where((e) =>
    !e.isPaid && e.plan.direction == PaymentDirection.outgoing &&
    (e.dueDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month + 1)))).fold(0, (sum, e) => sum + e.amountCents);

  int get monthIncoming => upcoming.where((e) =>
    e.plan.direction == PaymentDirection.incoming &&
    e.dueDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month + 1))).fold(0, (sum, e) => sum + e.amountCents);

  int get paidThisMonth => history.where((e) =>
    e.plan.direction == PaymentDirection.outgoing &&
    e.paidAt!.year == DateTime.now().year && e.paidAt!.month == DateTime.now().month
  ).fold(0, (sum, e) => sum + e.amountCents);

  int get lateCount => upcoming.where((e) => e.isLate).length;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    db.close();
    super.dispose();
  }
}
