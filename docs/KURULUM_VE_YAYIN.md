# VADESİ — kurulum ve mağaza yayını

## Teslimatın sınırları

Kaynak kod, otomatik derleme, SQLite, isteğe bağlı Firebase hesabı ve Premium bulut yedeği, OneSignal duyuruları ve yönetim paneli aynı projededir. Firebase/OneSignal projeleri sizin hesabınızda henüz oluşturulmadığından bulut özellikleri varsayılan olarak kapalıdır. Ödeme takibi ve dosya yedekleri hesap açmadan çalışır.

Firebase SQL değildir; Firestore belge veritabanıdır. Cihazda SQLite kullanılır. Çevrimiçi durum Firebase Realtime Database üzerinden yürür; Pusher hesabına ihtiyaç yoktur. Uygulamanın silindiği kesin olarak tespit edilemez. Yönetici yalnızca oturum açmış kullanıcıların bağlantısını ve son görülmesini görür; hesapsız yerel kullanıcılar izlenmez.

CI içindeki Android dosyası debug APK, iOS dosyası imzasız uygulamadır. Bunlar mağaza yükleme dosyası değildir. Gerçek hesaplarda push, satın alma, iade/yenileme ve imzalı cihaz testleri tamamlanmadan yayına çıkmayın. Mağaza kabulü garanti edilemez.

## 1. Yerel çalıştırma

Flutter 3.47.7 ve Java 17 kullanın. macOS'ta Xcode ve CocoaPods gerekir.

```sh
git clone https://github.com/otsho675-afk/VADE.git
cd VADE
git checkout codex/vadesi-platform-upgrade
bash scripts/kur.sh
flutter run
```

Windows PowerShell: `powershell -ExecutionPolicy Bypass -File scripts/kur.ps1`.
Web: `flutter run -d chrome`. Veriler aynı tarayıcı ve origin içinde saklanır; gizli mod, site verilerini silmek veya farklı port kullanmak aynı kayıtlara erişmez. JSON yedeği alın.
Android/iOS için proje kimliği başlangıçta `com.vadesi.vadesi`. Mağazaya ilk yüklemeden önce sahip olduğunuz benzersiz kimliği seçin; Firebase, OneSignal ve ödeme sunucusunda aynı kimliği kullanın.

## 2. Firebase hesabı ve veritabanları

1. [Firebase Console](https://console.firebase.google.com/) üzerinden kendi Google hesabınızla proje oluşturun. Firestore ve Realtime Database oluşturun; test modunda açık kurallar kullanmayın. Bölge seçimini kullanıcılarınız ve veri politikanızla uyumlu yapın.
2. Authentication → Sign-in method → Email/Password açın. Şifre ilkesi ve e-posta numaralandırma korumasını etkinleştirin. Hosting alanınızı Authorized domains listesine ekleyin.
3. Aynı projede Android, iOS ve Web uygulaması kaydedin. Paket/bundle kimliklerini eşleştirin. Her platformun Firebase API key/App ID bilgilerini kendi yapılandırma dosyasına yazın; API anahtarının platform kısıtlamalarını koruyun.
4. `config/firebase.example.json` dosyasını `config/firebase.android.json`, `config/firebase.ios.json`, `config/firebase.web.json` olarak kopyalayın. İlgili platformun anahtarını `FIREBASE_API_KEY` alanına, App ID'lerini ve gerçek Realtime Database URL'sini doldurun. `FIREBASE_ENABLED` değerini true yapın.
5. Gizlilik ve kullanım koşulları HTTPS adreslerini doldurun. Bu adresler yoksa Premium satın alma düğmeleri kapalı kalır; ücretsiz hesap oluşturma çalışır.
6. Flutter açık FirebaseOptions ile başlar. Sağlayıcı ayarlarının gerektirdiği `GoogleService-Info.plist` / `google-services.json` dosyalarını Firebase'den indirin; özellikle OneSignal FCM/APNs kurulumunu aşağıda tamamlayın.
7. Firebase CLI yükleyin, giriş yapın ve proje kimliğini seçin:

```sh
npm install -g firebase-tools
firebase login
cd backend/functions
npm install
npm test
cd ..
firebase use --add
firebase deploy --only firestore:rules,firestore:indexes,database
```

Firebase Authentication/Firestore/Realtime Database ücretsiz kotalarla başlayabilir. Bu projedeki sunucu satın alma doğrulaması, hesap silme ve duyuru gönderimi için Cloud Functions gerekir; deploy için Blaze faturalandırma hesabı zorunludur. Bütçe uyarıları kurun; uyarı harcamayı otomatik durdurmaz. [Resmî Functions kurulumu](https://firebase.google.com/docs/functions/get-started), [fiyatlandırma](https://firebase.google.com/pricing).

## 3. Premium ve sunucu

Premium özelliği: elle güncellenen, başka cihazda geri yüklenebilen 700 KB'a kadar bulut yedeği. Yerel kayıt, takvim, rapor ve dosya yedeği ücretsizdir. Süresi bitmiş Premium kullanıcısı mevcut bulut yedeğini indirebilir; yeni yedek yazamaz.

Her iki mağazada ürün kimlikleri:
- `vadesi_premium_monthly`: 1 aylık otomatik yenilenen abonelik.
- `vadesi_premium_yearly`: 1 yıllık otomatik yenilenen abonelik.

Fiyatı mağazalarda belirleyin; uygulama mağazanın yerelleştirilmiş fiyatını gösterir. Apple ürünlerini aynı abonelik grubuna koyun. Google Play'de ilgili base planları etkinleştirin. Vergi, banka ve ücretli uygulama sözleşmelerini tamamlayın.

Sunucu yalnızca mağaza tarafından doğrulanan, ürün/paket/hesap eşleşmesi doğru ve süresi geçmemiş aboneliği kabul eder. Kullanıcı kendi Premium belgesini yazamaz. Satın almanın uygulama hesabına bağlanması için satın almadan önce giriş zorunludur. Silinen hesabın aboneliği yeni hesaba otomatik taşınmaz; destek sürecinizde bu durumu açıklayın.

### Google doğrulama

Google Play Developer API'yi açın. Functions çalışma zamanı hizmet hesabına Play Console üzerinden yalnızca gereken sipariş/abonelik görüntüleme ve yönetme izinlerini verin. JSON özel anahtarı uygulamaya koymayın; sunucu Application Default Credentials kullanır. `ANDROID_PACKAGE` gerçek uygulama kimliği olmalıdır.

### Apple doğrulama

App Store Connect → Users and Access → Integrations → In-App Purchase üzerinden App Store Server API anahtarı oluşturun. Issuer ID, Key ID ve sayısal Apple App ID'yi alın. [Apple PKI](https://www.apple.com/certificateauthority/) sayfasından resmi kök sertifikaları indirip DER dosyalarının base64 dizisini JSON olarak hazırlayın. JWS imza zinciri bu güvenilir köklerle doğrulanır.

`backend/functions/.env.PROJECT_ID` içinde sunucu parametrelerini ayarlayın:

```dotenv
ANDROID_PACKAGE=com.vadesi.vadesi
APPLE_BUNDLE_ID=com.vadesi.vadesi
APPLE_APP_ID=GERCEK_SAYISAL_ID
APPLE_ISSUER_ID=ISSUER_ID
APPLE_KEY_ID=KEY_ID
APPLE_ENVIRONMENT=Production
ONESIGNAL_APP_ID=ONESIGNAL_APP_ID
```

Gizli değerleri Firebase Secret Manager'a terminalden girin; GitHub'a, uygulamaya veya sohbet mesajına koymayın:

```sh
firebase functions:secrets:set APPLE_PRIVATE_KEY
firebase functions:secrets:set APPLE_ROOT_CERTIFICATES_BASE64_JSON
firebase functions:secrets:set ONESIGNAL_REST_API_KEY
firebase deploy --only functions
```

Apple özel anahtar secret'ı .p8 dosyasının tam PEM içeriğidir. Sertifika secret'ı `["DER_BASE64", "..."]` biçimindedir. Sandbox için ayrı Firebase test projesi ve `APPLE_ENVIRONMENT=Sandbox` kullanın; test aboneliğini üretim erişimine dönüştürmeyin.

Sunucu abonelikleri 6 saatte bir kontrol eder. İadelerin/iptallerin yansıması bu süre kadar gecikebilir; sağlayıcı erişim hatasında son doğrulanmış bitiş korunur, uzatılmaz. Yüksek kullanıcı hacminde sayfalı zamanlayıcıyı görev kuyruğu ve mağaza sunucu bildirimleriyle genişletin. Premium bitişi Firestore kurallarında sunucu saatiyle denetlenir.

## 4. Yönetim paneli

`backend/admin/config.example.js` dosyasını `config.js` olarak kopyalayın ve Firebase Web uygulaması ayarlarını doldurun. Bunlar genel istemci ayarlarıdır; hizmet hesabı veya REST API secret'ı değildir.

Uygulamadan kendi yönetici hesabınızı oluşturun. Yetkiyi yalnızca proje sahibi terminalden versin:

```sh
gcloud auth application-default login
cd backend/functions
node set_admin.mjs PROJECT_ID ADMIN_EMAIL
cd ..
firebase deploy --only hosting
```

Google Play hesap silme URL alanına Hosting alanınızdaki `/delete.html` adresini girin; bu sayfa kullanıcıyı doğrulayıp aynı hesap silme fonksiyonunu çağırır.

Giriş yaptıktan sonra panel kayıtlı üye sayısını, aktif Premium sayısını, 50'şer üyeyi, çevrimiçi bağlantıları ve son 50 abonelik kaydını gösterir. Bu liste gelir muhasebesi değildir; gelir ve işlem raporu mağaza konsolundan alınır. Admin erişimi UI'ye ek olarak Firebase kuralları ve sunucuda custom claim ile korunur. Kullanıcıların finansal yedekleri admin istemcisine açılmaz.

## 5. OneSignal

1. [OneSignal](https://onesignal.com/) hesabınızda mobil uygulama oluşturun.
2. Android için Firebase Cloud Messaging v1 hizmet hesabını **OneSignal paneline** bağlayın. Özel hizmet hesabı JSON'unu uygulamaya veya repoya eklemeyin.
3. iOS için Apple Developer APNs .p8 anahtarı, Key ID ve Team ID'yi OneSignal paneline girin.
4. Xcode → Runner → Signing & Capabilities → Push Notifications ekleyin. Background Modes → Remote notifications açın. Doğru provisioning profile ve APNs entitlement ile imzalayın.
5. Uygulama yapılandırmasına `ONESIGNAL_APP_ID` yazın. REST API anahtarı yalnızca Functions secret'ında kalır.
6. Gerçek telefonda Hesabım → Duyuru bildirimleri iznini açın; yönetim panelinden test duyurusu gönderin.
7. Bu sürüm temel metin bildirimleri kullanır. Görsel/zengin bildirim ve iOS confirmed delivery istiyorsanız OneSignal'ın Notification Service Extension kurulumunu ayrıca tamamlayın.

Kullanıcı açıkça izin vermeden OneSignal başlatılmaz. OneSignal cihaz aboneliği Firebase UID ile eşleştirilmez; panel toplu duyuru gönderir. Geçersiz cihaz aboneliği uygulamanın silindiğini kesin kanıtlamaz. [OneSignal Flutter kurulum rehberi](https://documentation.onesignal.com/docs/flutter-sdk-setup).

## 6. Google Play

1. Play Console geliştirici hesabı açın; kimlik, iletişim, ödeme ve varsa kuruluş doğrulamasını tamamlayın.
2. Uygulamayı ve abonelik ürünlerini oluşturun. Uygulama adını, açıklamaları, ikonları, telefon/tablet ekran görüntülerini hazırlayın.
3. Android upload key oluşturup güvenli saklayın. Flutter'ın [Android imzalama rehberine](https://docs.flutter.dev/deployment/android#sign-the-app) göre release signing config ekleyin. Debug imzasını release için kullanmayın.
4. Yapılandırmayla AAB derleyin:

```sh
flutter build appbundle --release --dart-define-from-file=config/firebase.android.json
```

5. `build/app/outputs/bundle/release/app-release.aab` dosyasını Internal testing'e yükleyin. Play App Signing'i ayarlayın. Lisans test kullanıcılarıyla aylık/yıllık satın alma, geri yükleme, yenileme, iptal ve iade deneyin.
6. Data Safety bölümünde gerçek veri akışlarını beyan edin: hesap e-postası/UID, seçilirse finansal bulut yedeği, oturum/son görülme, satın alma bilgisi ve OneSignal cihaz verisi. Gereksiz reklam/veri toplama beyanları eklemeyin.
7. Gizlilik politikası, destek adresi, uygulama içi ve web üzerinden hesap silme yolu, yaş derecelendirmesi, reklam/abonelik beyanları ve inceleme test hesabını girin.
8. Yeni kişisel hesaplarda [kapalı test koşulu](https://support.google.com/googleplay/android-developer/answer/14151465) uygulanabilir: resmî sayfa en az 12 test kullanıcısının 14 gün kesintisiz katılımını belirtir. Kendi Console ekranınızdaki güncel koşulları izleyin.
9. Play Console'un güncel hedef API ve 16 KB sayfa boyutu kontrollerini geçin; native SQLite dahil AAB'yi gerçek cihazlarda test edin. Gerekirse SDK sürümlerini yükseltip bütün CI kontrollerini tekrarlayın.

## 7. Apple App Store

1. Apple Developer üyeliği ve App Store Connect hesabını tamamlayın.
2. Bundle ID, Push Notifications ve In-App Purchase ayarlarını yapın; abonelik grubu/ürünlerini, banka/vergi sözleşmelerini tamamlayın.
3. macOS'ta `ios/Runner.xcworkspace` açın, Team ve signing seçin. Minimum iOS 15 kullanılır. APNs yetkileri/provisioning uyumunu doğrulayın.
4. Üretim yapılandırmasıyla arşiv oluşturun:

```sh
flutter build ipa --release --dart-define-from-file=config/firebase.ios.json
```

5. Xcode Organizer veya Transporter ile yükleyin. TestFlight'ta gerçek cihazlarda bildirim, SQLite kalıcılığı, yedek geri yükleme, hesap silme ve StoreKit abonelik akışlarını test edin.
6. Ekran görüntüleri, destek/gizlilik URL'leri, yaş derecelendirmesi ve App Privacy bildirimlerini gerçek SDK davranışına göre doldurun. Kullanılan SDK'ların privacy manifest dosyalarını Xcode arşiv raporunda kontrol edin.
7. İnceleme ekibine çalışan test hesabı, Premium açıklaması ve test adımlarını verin. Abonelik geri yükleme, yönetim bağlantıları ve hesap silme erişilebilir kalmalıdır.
8. [Apple inceleme kurallarını](https://developer.apple.com/app-store/review/guidelines/) ve [Flutter iOS yayın rehberini](https://docs.flutter.dev/deployment/ios) kontrol ederek gönderin.

## 8. Yayın öncesi kabul testi

- Uçak modunda kayıt oluştur/düzenle/öde/geri al; uygulamayı kapatıp açınca kayıtları doğrula.
- Web'de sayfayı yenile; aynı origin'de SQLite kaydı korunsun.
- Aylık taksitlerde 29/30/31 Ocak başlangıcı, artık yıl ve gecikmiş ödemeleri dene.
- JSON dışa aktar/geri yükle; hatalı dosyada mevcut kayıtlar değişmesin.
- Android ve iOS'ta bildirim iznini reddet/kabul et, yeniden başlat, saat dilimi değişimini dene.
- İki farklı Firebase kullanıcısının birbirinin profil/yedeğini okuyamadığını doğrula.
- Normal kullanıcı admin paneline ve duyuru fonksiyonuna erişemesin.
- Premium olmadan bulut yazma reddedilsin; süresi dolan kullanıcı mevcut yedeğini indirebilsin.
- Sandbox satın alma/geri yükleme/yenileme/iptal/iade/hesap değiştirme ve kötü token testleri yap.
- Hesap silme bulut verisini ve oturumu kaldırsın; mağaza aboneliğinin ayrıca iptal edilmesi gerektiği görülsün.
- Üretim anahtarlarını doğru projeye yerleştir; GitHub ve ZIP içinde özel anahtar bulunmasın.

Yerel SQLite şifrelenmez. Firebase yedekleri erişim kurallarıyla korunur, uçtan uca şifrelenmez. Bu durumu gizlilik metninde açıkça anlatın. Hesap silme sonrasında satın alma tekrar kullanımını önlemek için kimliksizleştirilmiş tek yönlü sahiplik kaydı tutulur; saklama amacı/süresini kendi politikanızda belirleyin.
