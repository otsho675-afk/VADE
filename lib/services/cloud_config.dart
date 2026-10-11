import 'ios_firebase_config.dart';
import 'android_firebase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class CloudConfig {
  static const premiumEnabled = bool.fromEnvironment('PREMIUM_ENABLED');
  static const enabled = bool.fromEnvironment('FIREBASE_ENABLED', defaultValue: true);
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: AndroidFirebaseConfig.projectId);
  static String get apiKey => const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '') != '' ? const String.fromEnvironment('FIREBASE_API_KEY') : defaultTargetPlatform == TargetPlatform.iOS ? IosFirebaseConfig.apiKey : AndroidFirebaseConfig.apiKey;
  static const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: AndroidFirebaseConfig.senderId);
  static const databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: AndroidFirebaseConfig.databaseUrl);
  static const region = String.fromEnvironment('FIREBASE_FUNCTIONS_REGION', defaultValue: 'europe-west1');
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '80af0515-e91e-4967-9e13-e95c74a85c1a');
  static const privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: 'https://vade-b46fb.web.app/privacy.html');
  static const termsUrl = String.fromEnvironment('TERMS_URL', defaultValue: 'https://vade-b46fb.web.app/terms.html');
  static String get appId => kIsWeb
      ? const String.fromEnvironment('FIREBASE_WEB_APP_ID')
      : defaultTargetPlatform == TargetPlatform.iOS
          ? const String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: IosFirebaseConfig.appId)
          : defaultTargetPlatform == TargetPlatform.android ? const String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: AndroidFirebaseConfig.androidAppId) : '';
  static bool get configured => enabled && apiKey.isNotEmpty &&
      projectId.isNotEmpty && senderId.isNotEmpty && appId.isNotEmpty;
  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey, appId: appId, messagingSenderId: senderId, projectId: projectId,
    databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
    authDomain: '$projectId.firebaseapp.com',
    storageBucket: '$projectId.firebasestorage.app',
    iosBundleId: const String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: 'com.vadesi.vadesi'),
  );
}
