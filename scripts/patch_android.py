from pathlib import Path

root = Path(__file__).resolve().parent.parent
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    xml = manifest.read_text(encoding='utf8')
    if 'android.permission.POST_NOTIFICATIONS' not in xml:
        xml = xml.replace('<application', '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    '
                          '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n    <application')
    if 'ScheduledNotificationReceiver' not in xml:
        xml = xml.replace('</application>', '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
    </application>''')
    if 'android.permission.SCHEDULE_EXACT_ALARM' not in xml:
        xml = xml.replace('<application', '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />\n    <application')
    if 'android.permission.INTERNET' not in xml:
        xml = xml.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application')
    xml = xml.replace('android:label="vadesi"', 'android:label="VADESİ"')
    manifest.write_text(xml, encoding='utf8')

gradle_kts = root / 'android/app/build.gradle.kts'
gradle_groovy = root / 'android/app/build.gradle'
if gradle_kts.exists():
    gradle = gradle_kts.read_text(encoding='utf8')
    if 'isCoreLibraryDesugaringEnabled' not in gradle:
        gradle = gradle.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true')
    if 'coreLibraryDesugaring(' not in gradle:
        gradle += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    gradle_kts.write_text(gradle, encoding='utf8')
elif gradle_groovy.exists():
    gradle = gradle_groovy.read_text(encoding='utf8')
    if 'coreLibraryDesugaringEnabled' not in gradle:
        gradle = gradle.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true')
    if 'coreLibraryDesugaring ' not in gradle:
        gradle += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    gradle_groovy.write_text(gradle, encoding='utf8')
