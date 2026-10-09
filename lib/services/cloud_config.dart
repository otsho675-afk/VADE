import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class CloudConfig {
  static const enabled = bool.fromEnvironment('FIREBASE_ENABLED');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const region = String.fromEnvironment('FIREBASE_FUNCTIONS_REGION', defaultValue: 'europe-west1');
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
  static const privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  static String get appId => kIsWeb
      ? const String.fromEnvironment('FIREBASE_WEB_APP_ID')
      : defaultTargetPlatform == TargetPlatform.iOS
          ? const String.fromEnvironment('FIREBASE_IOS_APP_ID')
          : const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
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
