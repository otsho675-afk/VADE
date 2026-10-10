# VADESİ logo ve açılış rehberi

**Tek logo:** `assets/images/vadesi_mark.png` — ana marka rengi `#243F56`.

Uygulama simgesi Android/iOS'ta `flutter_launcher_icons` ile üretilir.
Android 12+ açılış için `values-v31/styles.xml`, eski Android sürümleri için
`launch_background.xml` kullanılır. iOS storyboard aynı V simgesini statik
gösterir. Android/iOS'un ilk sistem ekranı animasyonlu değildir; Flutter'ın
`LaunchScreen` bileşeni 1,35 saniye sonra mevcut giriş veya ana sayfayı
açar. Önceki ödeme ve hesap verilerine dokunmaz.

## Derlemeden önce yapılması gerekenler

Windows:
```powershell
powershell -ExecutionPolicy Bypass -File .\\scripts\\kur.ps1
flutter run
```

macOS/Linux:
```sh
bash scripts/kur.sh
flutter run
```

Yalnızca ikonları yenilemek için:
```sh
flutter pub get
dart run flutter_launcher_icons
```

Codemagic ve GitHub Actions, Android/iOS üretiminden önce otomatik olarak
`scripts/kur.sh` çalıştırır. Güncel ikonu görmek için yeni AAB/APK/IPA
paketini yükleyin. Telefon simge önbelleğini eski tutabilir. Uygulamayı
kaldırmak cihazdaki yerel ödeme kayıtlarını silebilir; önce JSON yedeği alın.
