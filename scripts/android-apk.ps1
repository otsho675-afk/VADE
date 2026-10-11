param([ValidateSet('debug', 'release')][string]$Mode = 'debug')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$configPath = Join-Path $projectRoot 'config/firebase.android.json'
if (!(Test-Path -LiteralPath $configPath)) {
    throw 'config/firebase.android.json bulunamadi. Once Firebase baglantisini hazirlayin.'
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ([string]$config.FIREBASE_ENABLED -ne 'true') {
    throw 'FIREBASE_ENABLED true olmali; aksi halde hesap ekrani acilmaz.'
}
foreach ($key in @('FIREBASE_PROJECT_ID', 'FIREBASE_API_KEY', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_ANDROID_APP_ID')) {
    if ([string]::IsNullOrWhiteSpace([string]$config.$key)) {
        throw "Eksik Firebase ayari: $key"
    }
}
flutter build apk "--$Mode" "--dart-define-from-file=$configPath"
if ($LASTEXITCODE -ne 0) { throw 'APK derlemesi basarisiz.' }
