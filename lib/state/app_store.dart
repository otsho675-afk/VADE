import '../services/cloud_config.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/cloud_service.dart';
import '../services/purchase_service.dart';
import '../services/remote_push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local_database.dart';
import '../models/payment.dart';
import '../services/reminder_service.dart';

class AppStore extends ChangeNotifier {
  final LocalDatabase db;
  final ReminderService reminders;
  AppStore({LocalDatabase? database, ReminderService? reminderService, CloudService? cloudService})
      : db = database ?? LocalDatabase(), reminders = reminderService ?? ReminderService(), cloud = cloudService ?? CloudService();
  final CloudService cloud;
  final remotePush = RemotePushService();
  late final purchases = PurchaseService(cloud);
  bool _servicesStarted = false;
  bool _disposed = false;
  bool get supportsNotifications => reminders.supported;
  List<DueItem> items = [];
  bool loading = true;
  String? error;
  String? reminderError;
  ThemeMode themeMode = ThemeMode.system;
  bool notificationsEnabled = false;
  bool notificationIntroReady = false;
  bool notificationIntroSeen = false;
  int notifyHour = 9;

  Future<void> initialize() async {
    if (!_servicesStarted) {
      _servicesStarted = true;
      unawaited(_initializeServices());
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == prefs.getString('theme_mode'), orElse: () => ThemeMode.system);
      notificationsEnabled = supportsNotifications && (prefs.getBool('notifications_enabled') ?? false);
      notificationIntroSeen = (prefs.getBool('notification_intro_seen') ?? false) || notificationsEnabled;
      notificationIntroReady = true;
      notifyHour = (prefs.getInt('notify_hour') ?? 9).clamp(0, 23);
      await reminders.initialize();
      await refresh();
    } catch (e, stack) {
      debugPrint('Local initialization failed: $e\\n$stack');
      error = 'Başlatma sırasında hata oluştu: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeServices() async {
    await cloud.initialize();
    if (_disposed) return;
    try { await remotePush.initialize(); if (CloudConfig.premiumEnabled) await purchases.initialize(); }
    catch (_) { cloud.error = 'Bildirim veya mağaza bağlantısı kurulamadı.'; }
    notifyListeners();
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

  /// The one-time explainer is saved independently from the system's permission.
  /// Dismissing it never requests notification permission.
  Future<void> finishNotificationIntro() async {
    notificationIntroSeen = true;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool('notification_intro_seen', true);
  }

  Future<bool> setNotifications(bool enabled) async {
    // Explicit user action is the only place that invokes the system prompt.
    await finishNotificationIntro();
    if (enabled && !(await reminders.requestPermissions())) return false;
    notificationsEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool('notifications_enabled', enabled);
    await refresh();
    notifyListeners();
    return true;
  }

  Future<void> setNotifyHour(int value) async {
    if (value < 0 || value > 23) throw ArgumentError.value(value, 'hour');
    notifyHour = value;
    await (await SharedPreferences.getInstance()).setInt('notify_hour', value);
    await refresh();
    notifyListeners();
  }

  /// All open installments, oldest due date first; unlike upcoming, never de-duplicated.
  List<DueItem> get unpaidItems => items.where((e) => !e.isPaid).toList()
    ..sort((a, b) {
      final order = a.dueDate.compareTo(b.dueDate);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

  /// One nearest installment per plan for the compact dashboard.
  List<DueItem> get upcoming {
    final map = <int, DueItem>{};
    for (final item in unpaidItems) {
      map.putIfAbsent(item.planId, () => item);
    }
    return map.values.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<DueItem> get history => (items.where((e) => e.isPaid).toList()
    ..sort((a, b) => b.paidAt!.compareTo(a.paidAt!)));

  List<DueItem> planItems(int id) => items.where((e) => e.planId == id).toList()
    ..sort((a, b) => a.sequence.compareTo(b.sequence));

  int get monthOutgoing => items.where((e) =>
    !e.isPaid && e.plan.direction == PaymentDirection.outgoing &&
    (e.dueDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month + 1)))).fold(0, (sum, e) => sum + e.amountCents);

  int get monthIncoming => items.where((e) =>
    !e.isPaid && e.plan.direction == PaymentDirection.incoming &&
    e.dueDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month + 1))).fold(0, (sum, e) => sum + e.amountCents);

  int get paidThisMonth => history.where((e) =>
    e.plan.direction == PaymentDirection.outgoing &&
    e.paidAt!.year == DateTime.now().year && e.paidAt!.month == DateTime.now().month
  ).fold(0, (sum, e) => sum + e.amountCents);

  /// Count occurrences, not plans: three overdue installments are three missed payments.
  int get lateCount => unpaidItems.where((e) => e.isLate).length;

  int get lateOutgoingAmount => unpaidItems.where((e) =>
    e.isLate && e.plan.direction == PaymentDirection.outgoing
  ).fold<int>(0, (sum, e) => sum + e.amountCents);

  int get next7DaysOutgoing {
    final today = dateOnly(DateTime.now());
    final lastDay = today.add(const Duration(days: 7));
    return unpaidItems.where((e) =>
      e.plan.direction == PaymentDirection.outgoing &&
      !dateOnly(e.dueDate).isBefore(today) && dateOnly(e.dueDate).isBefore(lastDay)
    ).fold<int>(0, (sum, e) => sum + e.amountCents);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cloud.dispose();
    purchases.dispose();
    db.close();
    super.dispose();
  }
}
