# VADESİ — Taksit, fatura ve alacak takibi

Flutter ile Android, iOS ve web için kişisel ödeme takip uygulaması.

## 1.1 geliştirmeleri

- Logo bölümündeki geçersiz const ifadeleri düzeltildi.
- Flutter yerelleştirmeleriyle uyumlu intl ^0.20.3.
- Android/iOS SQLite, web için SQLite WASM + tarayıcı depolaması, Windows/Linux için SQLite FFI.
- Günlük ödeme takvimi ve seçili ayın borç/alacak toplamları.
- JSON yedekleme, doğrulanan yedeği işlem içinde geri yükleme, CSV dışa aktarma.
- Gecikmiş tüm taksitleri içeren toplam; borç dağılımından alacakların ayrılması.
- Taksit, fatura, abonelik, borç/alacak, arama, filtre, geçmiş, geri alma, IBAN kontrolü ve temalar.
- Yerel bildirimler yalnızca Android/iOS'ta etkinleştirilebilir; Türkiye saatine göre planlanır.
- Veri tabanı işlemleri ve farklı ekran genişlikleri için testler.

## Kurulum

Güncel **Flutter stable**, Android için Android SDK/JDK 17; iOS için macOS ve Xcode gerekir.

Windows:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\kur.ps1
flutter run
```

macOS/Linux:
```sh
bash scripts/kur.sh
flutter run
```

Betiğin oluşturduğu Android/iOS dosyaları mevcut platform klasörlerini değiştirmez.
iOS için macOS'ta kurulum betiğini çalıştırın. Web SQLite dosyalarını yenilemek için:

```sh
flutter pub get
dart run sqflite_common_ffi_web:setup
flutter run -d chrome
```

Web sürümünde kayıtlar kullanılan tarayıcı ve site adresine bağlıdır. Tarayıcı verilerini
temizlemek kayıtları siler. HTTPS veya localhost üzerinden çalıştırın; düzenli JSON yedeği alın.
Web ve masaüstünde arka plan yerel bildirimleri sunulmaz.

## Doğrulama ve indirmeler

[GitHub Actions](https://github.com/otsho675-afk/VADE/actions) her değişiklikte:
1. Bağımlılık çözümleme, Flutter analyze, testler ve web release derlemesi.
2. Android debug APK derlemesi.
3. iOS release derlemesi (imzasız).
4. Android/iOS iskeletleri ve web SQLite dosyalarını içeren VADESI.zip paketi.

Başarılı çalışmanın **Artifacts** bölümünden indirin:
- VADESI-Complete-Source: tam kaynak ZIP'i.
- VADESI-Android-Debug: cihazda denemek için APK.
- VADESI-Web: web sunucusuna koyulabilecek çıktı.
- VADESI-iOS-Unsigned: imzalanmamış iOS uygulaması; telefona doğrudan kurulamaz.

Kontrollerin sonucu Actions'ta görülür; iş akışının bulunması testlerin geçtiği anlamına gelmez.
```sh
flutter analyze --no-fatal-infos
flutter test
flutter build web --release
```

## Mağaza yayını

Android debug APK, Google Play yayın paketi değildir. Play için kendi uygulama kimliğiniz,
yükleme anahtarınız ve release imzalama yapılandırmanızla AAB üretin.
iOS için Apple Developer ekibi, benzersiz bundle ID, sertifikalar ve provisioning gerekir.
Varsayılan com.vadesi.vadesi kimliğini ilk yayından önce kendi kimliğinizle değiştirin.
İmzalama anahtarlarını veya hesap parolalarını depoya eklemeyin.

Mağaza açıklamaları, gizlilik politikası, ekran görüntüleri, veri güvenliği formları ve
gerçek cihaz testleri yayın öncesinde tamamlanmalıdır. SQLite ve JSON yedekleri şifreli değildir.
Uygulama bankadan para göndermez ve kurum borçlarını otomatik sorgulamaz.

Bildirimler Türkiye saat diliminde tam saatlere planlanır. İşletim sistemi izinleri ve pil
yönetimi teslimatı etkileyebilir. Her planın en eski ödenmemiş kaydı için 5 gün önce, 1 gün önce, vade günü ve vade ertesi uyarıları hazırlanır; en yakın 60 bildirim saklanır. Gecikmiş kayıtlar yeniden planlandığında seçili saatin bir sonraki gelişinde uyarılır.
Fatura/aboneliklerde bir sonraki dönem, önceki dönem ödendiğinde oluşturulur.


## Firebase, Premium ve yönetim paneli

İsteğe bağlı bulut hizmetleri ve mağaza kurulumu için [Kurulum ve yayın kılavuzu](docs/KURULUM_VE_YAYIN.md). Firebase/OneSignal hesabı ve mağaza anahtarları bağlanmadan bulut/ödeme hizmetleri aktif değildir. Yerel takip çalışır.

### Hesap bağlantısıyla Android APK

Yerel Firebase ayarları hazırsa:
powershell -ExecutionPolicy Bypass -File scripts/android-apk.ps1

Bu betik config/firebase.android.json ayarlarını derlemeye dahil eder.
Android için VADESİ Firebase istemci ayarları varsayılan olarak kaynakta bulunur; düz flutter build apk komutunda da hesap kaydı aktiftir. --dart-define değerleri bu varsayılanları değiştirebilir.
iOS derlemesine de kendi FIREBASE_IOS_APP_ID değerini içeren ayar dosyası
--dart-define-from-file ile verilmelidir.

Bildirim almak için Ayarlar > Ödeme bildirimleri açık olmalı ve telefonun
bildirim izni verilmelidir. Ödenen veya silinen kayıtların uyarıları kaldırılır.