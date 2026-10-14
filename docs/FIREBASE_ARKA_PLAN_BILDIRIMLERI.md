# VADESİ — ÜCRETSİZ kapalı uygulama bildirimleri (Firebase Spark)

**Blaze, Cloud Functions ve kart ekleme gerekmiyor.** Firebase Cloud Messaging (FCM) ücretsizdir. Firestore'un Spark ücretsiz kotaları vardır. Bu projenin herkese açık GitHub deposunda standart GitHub-hosted Actions görevleri de ücretsiz çalışır.

## Çalışma şekli

- **İnternetsiz / hesap açmadan**: Android ve iOS yerel bildirimleri önceden planlar. Uygulama arka planda veya normal biçimde kapalı olduğunda işletim sistemi bildirimi gösterir. Telefonun bildirim izni ve üreticinin pil kısıtlamaları geçerlidir.
- **Hesapla + internetle**: Telefon Firebase FCM token'ını ve vade hatırlatma zamanlarını Firestore `push_devices` belgesine yazar. Ödeme tutarı, kişi adı veya IBAN **FCM belge gövdesine aktarılmaz**.
- **Ücretsiz sunucu yerine GitHub Actions**: `.github/workflows/free-firebase-push.yml` her 15 dakikada bir çalışmayı dener, `backend/functions/dispatch_push_spark.js` Firestore'da sadece zamanı gelen cihazları sorgular ve FCM bildirimlerini gönderir.
- **Kota koruması**: `nextDueAtMillis` indeksli sorgu kullanılır; her çalıştırmada en fazla 400 zamanı gelen cihaz değerlendirilir.
- **Önemli**: Aynı hatırlatma yerel + FCM yolundan geldiğinde bazı telefonlarda çift bildirim oluşabilir. İnternet kesintisinde yerel bildirimi korumak için iki katman açıktır.

## Bir defalık ücretsiz kurulum

### A) Firebase projesi

1. Firebase Console'da **vade-b46fb** projesini **Spark (ücretsiz)** planında tutun. Blaze açmayın.
2. Firebase → **Project settings (Proje ayarları) → Service accounts (Hizmet hesapları) → Firebase Admin SDK → Generate new private key (Yeni özel anahtar oluştur)**: bir JSON dosyası indirin.
3. JSON içeriğini **kimseyle, sohbetle ve GitHub kaynak koduyla paylaşmayın**. Doğrudan aşağıdaki GitHub secret alanına yapıştırın.
4. Firebase → **Project settings → Cloud Messaging → Apple app configuration**: iOS'ta APNs bildirimleri istiyorsanız kendi Apple uygulamanıza ait `.p8` APNs anahtarı, Key ID ve Team ID Firebase'e tanımlanmalıdır. Apple Developer'da Push Notifications yetkisi ve doğru provisioning profile da gereklidir.
5. Flutter uygulaması: Firebase Android ve iOS uygulamaları `com.vadesi.vadesi` kimliğiyle eşleşmelidir.

### B) GitHub Actions gizli anahtarı

1. [VADE deposu](https://github.com/otsho675-afk/VADE/settings/secrets/actions) → **Settings → Secrets and variables → Actions → New repository secret**.
2. **Name:** `VADE_FIREBASE_SERVICE_ACCOUNT_JSON`
3. **Secret:** İndirdiğiniz *tüm* JSON dosyasının içeriği.
4. **Add secret** diyerek kaydedin. GitHub'da dosya olarak commit etmeyin.
5. GitHub **Actions → Free Firebase background reminders (Spark) → Run workflow** ile hemen test edin. `Spark push: inspected ...` mesajı görülmelidir. Henüz zamanı gelen kullanıcı yoksa `sent 0` normaldir.

### C) Firestore güvenlik kurallarını ücretsiz dağıtma

**Cloud Functions dağıtımı yapmayın.** Yerel terminal:

```powershell
npm install -g firebase-tools
firebase login
cd backend
firebase use vade-b46fb
firebase deploy --only firestore:rules
```

Bu işlem Firestore kurallarını Spark üzerinde dağıtır. Firestore veri tabanı henüz oluşturulmadıysa Firebase Console → Firestore Database bölümünden uygun konumda önce oluşturun. Bölgenin değiştirilmesi sonradan kolay değildir.

### D) Gerçek cihaz testi

1. Yeni Flutter sürümünü mağazaya / telefona kurun.
2. VADE'de **Ödeme hatırlatmalarını** tek dokunuşla açıp bildirim iznini onaylayın.
3. Firebase hesabına giriş yapın ve yakın tarihli bir ödeme ekleyin.
4. Firestore → `push_devices/{userId}_{deviceId}` belgesinde `fcmToken`, `reminders`, `nextDueAtMillis` kayıtlarının geldiğini doğrulayın.
5. GitHub Actions görevini manuel çalıştırın veya zamanı gelen bildirimi bekleyin. Uygulamayı öne getirmeden arka plan ve normal kapalı durumda kontrol edin. iOS için fiziksel iPhone gerekir.

## Ücretsiz kullanımdaki sınırlar

- **GitHub planlı görevleri gecikebilir**; belirli dakika garantisi yok. Her 15 dakika hedeflenir, kesin bildirim saati için yerel bildirim planlaması kullanılır.
- Herkese açık depolarda standart GitHub-hosted Actions ücretsizdir. Özel depoya geçerseniz GitHub'ın ücretsiz dakika sınırları değişir.
- GitHub, **60 gün hareketsiz kalan herkese açık depolarda** planlı görevleri otomatik devre dışı bırakabilir. Actions sayfasından yeniden etkinleştirmek gerekir.
- Firebase Spark'ta Firestore günlük okuma/yazma kotaları vardır; aşılırsa hizmet duraklatılabilir, **otomatik ücret kesilmez**.
- İnternet kapanırsa uzaktan FCM gönderimi başarısız olabilir; telefondaki yerel hatırlatmalar bundan bağımsızdır.
- Android'de ayarlardan **Zorla durdur** ve bazı üretici pil kısıtlamaları, iOS'ta bildirim izinleri/Focus görünürlüğü sınırlayabilir.
- Gönderimin başlaması için **GitHub secret, Firestore kuralları ve yeni mobil uygulama sürümü** gerekir; kodu GitHub'a göndermek tek başına canlı sistemi çalıştırmaz.

## Kullanılan dosyalar

- `.github/workflows/free-firebase-push.yml` — ücretsiz 15 dakikalık tetikleyici
- `backend/functions/dispatch_push_spark.js` — Firebase Admin SDK ile FCM gönderimi
- `backend/functions/push_reminders.js` — bildirim zamanı ve tekrarlama kontrolü
- `lib/services/firebase_push_service.dart` — FCM cihaz token ve plan eşitleme
- `backend/firestore.rules` — kullanıcıya özel yetkilendirme

**Not:** Diğer, isteğe bağlı premium/satın alma Cloud Functions işlevleri bu arka plan bildirim mekanizmasının parçası değildir. Bu bildirim özelliği Blaze gerektirmez.
