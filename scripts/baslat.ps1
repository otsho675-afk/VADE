# Run from PowerShell: .\scripts\baslat.ps1
param([switch]$Apk)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$configPath = Join-Path (Get-Location) 'config/firebase.android.json'
if (-not (Test-Path $configPath)) {
  $googlePath = Join-Path (Get-Location) 'google-services.json'
  if (Test-Path $googlePath) {
    $google = Get-Content $googlePath -Raw | ConvertFrom-Json
    $client = $google.client | Where-Object {
      $_.client_info.android_client_info.package_name -eq 'com.vadesi.vadesi'
    } | Select-Object -First 1
    if (-not $client) { throw 'Firebase Android paket adi com.vadesi.vadesi olmali.' }
    $config = Get-Content 'config/firebase.example.json' -Raw | ConvertFrom-Json
    $config.FIREBASE_ENABLED = $true
    $config.FIREBASE_PROJECT_ID = $google.project_info.project_id
    $config.FIREBASE_API_KEY = $client.api_key[0].current_key
    $config.FIREBASE_ANDROID_APP_ID = $client.client_info.mobilesdk_app_id
    $config.FIREBASE_MESSAGING_SENDER_ID = [string]$google.project_info.project_number
    if ($google.project_info.project_id -eq 'vade-b46fb') {
      $config.FIREBASE_DATABASE_URL = 'https://vade-b46fb-default-rtdb.europe-west1.firebasedatabase.app'
      $config.ONESIGNAL_APP_ID = '80af0515-e91e-4967-9e13-e95c74a85c1a'
    }
    [System.IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 10),
      [System.Text.UTF8Encoding]::new($false))
  } else {
    throw 'Hesap baglantisi icin google-services.json dosyasini proje klasorune koy veya config/firebase.android.json olustur.'
  }
}
# Generate native projects, notification settings and branded launcher icons.
& .\scripts\kur.ps1
if ($Apk) {
  flutter build apk --debug "--dart-define-from-file=$configPath"
} else {
  flutter run "--dart-define-from-file=$configPath"
}
if ($LASTEXITCODE -ne 0) { throw 'Flutter islemi tamamlanamadi; yukaridaki hata mesajini kontrol edin.' }
