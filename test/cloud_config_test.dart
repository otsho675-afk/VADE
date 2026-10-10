import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/services/cloud_config.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('Android includes Firebase configuration without build flags', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(CloudConfig.configured, isTrue);
    expect(CloudConfig.projectId, 'vade-b46fb');
    expect(CloudConfig.appId, startsWith('1:570041657692:android:'));
  });
  test('iOS uses its own registered Firebase app identifier', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(CloudConfig.configured, isTrue);
    expect(CloudConfig.appId, startsWith('1:570041657692:ios:'));
  });
}
