# VADESI - Android/iOS Flutter native host builder.
# Run from the project root: powershell -ExecutionPolicy Bypass -File .\scripts\kur.ps1
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK PATH icinde bulunamadi. Flutter kurulumunu tamamlayin.'
}
Write-Host 'VADESI Flutter yerel platform dosyalari hazirlaniyor...'
$tmp = Join-Path $env:TEMP ('vadesi_native_' + [guid]::NewGuid().ToString('N'))
try {
  flutter create --platforms=android,ios --org com.vadesi --project-name vadesi $tmp
  if ($LASTEXITCODE -ne 0) { throw 'Flutter create basarisiz.' }
  if (-not (Test-Path (Join-Path $projectRoot '.metadata'))) {
    Copy-Item (Join-Path $tmp '.metadata') (Join-Path $projectRoot '.metadata')
  }
  foreach ($folder in @('android', 'ios')) {
    if (-not (Test-Path (Join-Path $projectRoot $folder))) {
      Copy-Item -Recurse -Force (Join-Path $tmp $folder) (Join-Path $projectRoot $folder)
    }
  }

  $manifest = Join-Path $projectRoot 'android/app/src/main/AndroidManifest.xml'
  if (Test-Path $manifest) {
    $xml = Get-Content $manifest -Raw -Encoding UTF8
    if (-not $xml.Contains('android.permission.POST_NOTIFICATIONS')) {
      $xml = $xml.Replace('<application', "<uses-permission android:name=`"android.permission.POST_NOTIFICATIONS`" />`n    <uses-permission android:name=`"android.permission.RECEIVE_BOOT_COMPLETED`" />`n    <application")
    }
    if (-not $xml.Contains('ScheduledNotificationReceiver')) {
      $receivers = @'
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
'@
      $xml = $xml.Replace('</application>', $receivers + '    </application>')
    }
    if (-not $xml.Contains('android.permission.INTERNET')) {
      $xml = $xml.Replace('<application', "<uses-permission android:name=`"android.permission.INTERNET`" />`n    <application")
    }
    $xml = $xml.Replace('android:label="vadesi"', 'android:label="VADESİ"')
    [System.IO.File]::WriteAllText($manifest, $xml, (New-Object System.Text.UTF8Encoding $false))
  }

  $kts = Join-Path $projectRoot 'android/app/build.gradle.kts'
  $groovy = Join-Path $projectRoot 'android/app/build.gradle'
  if (Test-Path $kts) {
    $gradle = Get-Content $kts -Raw -Encoding UTF8
    if (-not $gradle.Contains('isCoreLibraryDesugaringEnabled')) {
      $gradle = $gradle.Replace('compileOptions {', "compileOptions {`n        isCoreLibraryDesugaringEnabled = true")
    }
    if (-not $gradle.Contains('coreLibraryDesugaring(')) {
      $gradle += "`n dependencies {`n    coreLibraryDesugaring(`"com.android.tools:desugar_jdk_libs:2.1.4`")`n}`n"
    }
    [System.IO.File]::WriteAllText($kts, $gradle, (New-Object System.Text.UTF8Encoding $false))
  } elseif (Test-Path $groovy) {
    $gradle = Get-Content $groovy -Raw -Encoding UTF8
    if (-not $gradle.Contains('coreLibraryDesugaringEnabled')) {
      $gradle = $gradle.Replace('compileOptions {', "compileOptions {`n        coreLibraryDesugaringEnabled true")
    }
    if (-not $gradle.Contains('coreLibraryDesugaring ')) {
      $gradle += "`n dependencies {`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'`n}`n"
    }
    [System.IO.File]::WriteAllText($groovy, $gradle, (New-Object System.Text.UTF8Encoding $false))
  }

  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Paketler indirilemedi. Baglantinizi ve Flutter SDK surumunu kontrol edin.' }
  dart run sqflite_common_ffi_web:setup
  if ($LASTEXITCODE -ne 0) { throw 'Web SQLite dosyalari hazirlanamadi.' }
  dart run flutter_launcher_icons
  if ($LASTEXITCODE -ne 0) { throw 'Uygulama simgesi olusturulamadi.' }
  Write-Host ''
  Write-Host 'HAZIR! Uygulamayi baslatmak icin: flutter run'
  Write-Host 'APK: flutter build apk --release'
  Write-Host 'AAB: flutter build appbundle --release (Play Store icin imzalama gerekir)'
} finally {
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
