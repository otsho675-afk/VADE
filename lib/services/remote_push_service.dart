import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_config.dart';

class RemotePushService {
  bool enabled = false;
  bool _initialized = false;
  bool get available => CloudConfig.oneSignalAppId.isNotEmpty && !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!available) return;
    enabled = (await SharedPreferences.getInstance()).getBool('remote_push_enabled') ?? false;
    if (enabled) await _start();
  }

  Future<void> _start() async {
    if (_initialized) return;
    await OneSignal.consentRequired(true);
    await OneSignal.initialize(CloudConfig.oneSignalAppId);
    await OneSignal.consentGiven(true);
    _initialized = true;
  }

  Future<bool> setEnabled(bool value) async {
    if (!available) return false;
    if (value) {
      await _start();
      if (!await OneSignal.Notifications.requestPermission(true)) return false;
      await OneSignal.User.pushSubscription.optIn();
    } else if (_initialized) {
      await OneSignal.User.pushSubscription.optOut();
      await OneSignal.consentGiven(false);
      _initialized = false;
    }
    enabled = value;
    await (await SharedPreferences.getInstance()).setBool('remote_push_enabled', value);
    return true;
  }
}
