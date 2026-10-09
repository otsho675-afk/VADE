# VADESİ — Taksit, fatura ve alacak takipçisi

**Flutter / Android / iOS — yerel SQLite veritabanı — sunucu gerektirmez.**

## Windows kurulum (en kısa yol)

1. ZIP dosyasını bir klasöre çıkarın, VS Code ile klasörü açın.
2. Flutter SDK ve Android SDK kurulu olsun. VS Code terminalinde:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\kur.ps1
   flutter run
   ```

   Kurulum betiği Flutter'ın **resmî Android/iOS platform iskeletini otomatik oluşturur**, bildirim izinlerini / yeniden başlatma alıcılarını ve Android tarih API desugaring ayarını ekler, paketleri indirir ve uygulama simgesini üretir.

3. Sonradan: `flutter pub get` / `flutter run` yeterli.
4. Test: `flutter test`.
5. APK: `flutter build apk --release`.
6. Google Play AAB: `flutter build appbundle --release` (yayına almak için ayrıca kendi imzalama anahtarınız gerekir).

**macOS / Linux:** `bash scripts/kur.sh` ardından `flutter run`. iOS uygulamasını derlemek ve imzalamak için Mac + Xcode gerekir.

> Not: Bu çalışma ortamında Flutter SDK mevcut olmadığı için derleme yapılmadı. İlk kurulum sırasında paket sürümleri Flutter sürümünüze göre güncellenmeyi gerektirebilir. Android/iOS klasörleri bilinçli olarak ZIP'e sabitlenmedi; tek komutla kullandığınız Flutter SDK'nın güncel resmî şablonundan üretilir.

## Özellikler

- Resmî ve sade arayüz; açık / koyu / sistem teması.
- Mobil ve tablet/masaüstü genişliğine uyarlanabilen ekranlar, mobilde alt menü, geniş ekranda sol menü.
- Taksit, elektrik / su / doğalgaz / internet / telefon faturası, abonelik, tek seferlik ödeme.
- Kişisel borçlar **ve alacaklar**, IBAN / karşı taraf / not.
- Taksit sayısı, taksit tutarı ve ilk ödeme tarihi; tüm taksitler otomatik oluşturulur.
- Ayın 29/30/31'indeki taksitler kısa aylarda ayın son gününe ayarlanır.
- “Ödendi / Tahsil edildi” düğmesi sonraki taksite geçer; faturada sonraki ay oluşturulur.
- Ödeme geçmişi, geri alma, düzenleme, vade değiştirme, silme.
- SQLite: telefon kapansa bile kayıtlar kalır; sunucu veya kullanıcı hesabı yoktur.
- Android/iOS yerel zamanlanmış hatırlatma: 5 gün önce, 1 gün önce, vade günü. Varsayılan 09.00; ayarlardan değiştirilebilir.
- Tüm bekleyen ödeme kartlarında arama, filtre, rapor ve özet.
- IBAN kopyalama, Türkiye IBAN kontrolü, kuruş bazlı parasal kayıt.

## Önemli davranışlar

- Ödeme onayı **gerçek para transferi yapmaz**, yalnızca kullanıcının kaydını günceller.
- Faturalar kurumlardan **otomatik sorgulanmaz**. Kullanıcı tutarı ve vadesini girer, sonraki dönemin planı oluşturulur. Kurumların fatura API entegrasyonu bu ilk sürüme dahil değildir.
- İlk ödeme kaydından sonra bildirim izni için uygulama kullanıcıya sorar; ayrıca **Ayarlar** bölümünden yönetilebilir. OS kısıtları, telefonun kapalı olması ve pil yönetimi nedeniyle bildirimlerin kesin zamanında gönderimi garanti değildir.
- Uygulama Türkçe hedefli ve varsayılan `Europe/Istanbul` saat dilimiyle planlar. Türkiye dışı kullanıcılar için dinamik saat dilimi desteği eklenmelidir.
- Veritabanı **şifreli değildir**. Hassas verileri bu sürümde yalnızca cihazın fiziksel/sistem güvenliğine güvenerek saklayın. Üretim sürümünde şifreli yerel saklama, yedekleme ve kurtarma geliştirmesi önerilir.
- Android/iOS bildirim davranışları gerçek cihaz üzerinde doğrulanmalıdır. iOS bekleyen yerel bildirim sınırı için en yakın 20 planın hatırlatmaları hazırlanır.
- Kayıtlar cihazdan silinir veya uygulama kaldırılırsa ayrıca yedek olmadan geri getirilemez.

## Proje yapısı

```text
lib/
  main.dart
  models/payment.dart
  data/local_database.dart
  services/reminder_service.dart
  state/app_store.dart
  ui/app_theme.dart
  ui/widgets/common.dart
  ui/screens/home_shell.dart
  ui/screens/payment_form_page.dart
  ui/screens/payment_detail_page.dart
scripts/kur.ps1
scripts/kur.sh
scripts/patch_android.py
test/payment_logic_test.dart
```
