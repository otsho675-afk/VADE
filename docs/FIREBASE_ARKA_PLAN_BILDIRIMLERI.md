# VADESİ: arka plan / kapalı uygulama bildirimleri

## Nasıl çalışıyor?

- **Yerel hatırlatma**: Mobil uygulama, geçmişte planlanan vade uyarılarını telefonun bildirim servisine bırakır. Açık kalması ve Firebase'e erişmesi gerekmez. Android'de boot receiver; iOS'ta UNUserNotificationCenter kullanılır.
- **Uzaktan bildirim**: Bildirim izni veren ve Firebase hesabına giriş yapan kullanıcıların her cihazı, kendi FCM token'ını ve sıradaki 60 hatırlatmayı Firestore `push_devices` koleksiyonuna yazar. `dispatchVadeReminders` Cloud Function'ı her 15 dakikada zamanı gelen uyarıları FCM notification payload ile gönderir.
- **Giriş yapılmamış kullanıcılar**: Sunucuya ödeme bilgisi aktarılmaz; mevcut yerel hatırlatmalar devam eder.
- **İzin**: Bildirim izni, uygulamadaki tek hatırlatma açma işleminde istenir. Yeniden açılışta otomatik izin penceresi gösterilmez.
- **Veri güncelleme**: Vade düzenleme, ödeme işaretleme veya bildirimleri kapatma işlemleri açıkken senkronize olur. Çevrimdışı yapılan değişiklikler bağlantı döndüğünde/uygulama açıldığında güncellenir.
- **Yinelenen bildirim riski**: Hem yerel hem FCM etkinse bazı cihazlarda aynı vade için iki uyarı çıkabilir. Yerel zamanlayıcıyı kapatmayarak internet yokken hatırlatmaları koruyoruz.

## Firebase kurulumu ve dağıtım

1. Firebase projesi: `vade-b46fb`. Firebase Console → Project settings → Cloud Messaging → **Apple app configuration** bölümüne ilgili iOS uygulamasının APNs `.p8` key'ini **Key ID ve Team ID** ile ekleyin. Key dosyası veya sunucu anahtarı GitHub'a konulmaz.
2. Apple Developer portalında `com.vadesi.vadesi` uygulama kimliğinde Push Notifications özelliği, Xcode Signing & Capabilities ekranında Push Notifications ve Background Modes → Remote notifications yetkisi etkin olmalı. Dağıtılan iOS imzasındaki `aps-environment` değeri üretim için `production` olmalı; projedeki development şablonunun değiştirilmesi tek başına yeterli değildir.
3. Firebase Android ve iOS uygulamaları doğru package/bundle ID ile kayıtlı olmalı. İmzalanan Play sürümünde Google Play Hizmetleri desteği bulunmalıdır.
4. Firebase CLI yetkili bir terminalde:
   ```powershell
   cd backend
   firebase use vade-b46fb
   firebase deploy --only firestore:rules,functions:dispatchVadeReminders
   ```
   **Cloud Functions / Cloud Scheduler deploy için Blaze (faturalandırma açık) gerekir.** Mevcut projede bunun etkin olup olmadığını buradan doğrulayamadım.
5. Yeni Flutter sürümünü Android/iOS için derleyip kurun. Test için **fiziksel iPhone** ve Google Play Services destekleyen Android cihaz kullanın.
6. Uygulamadan bildirimleri açın ve hesabınıza giriş yapın. Firestore `push_devices/{uid}_{cihazKimliği}` alanında `enabled=true`, `fcmToken` ve `reminders` göründüğünü kontrol edin. Bunları kimseyle paylaşmayın.
7. Bir sonraki vade saatini geçecek şekilde uygulamayı arka plana atarak ve tamamen kapatarak test edin. Cloud Functions loglarında `dispatchVadeReminders` çalışmasını inceleyin.

## Sınırlar

FCM push teslimatı anlık veya yüzde yüz garantili değildir. Kullanıcının bildirim izni, iOS Focus, pil ve üretici kısıtlamaları etkileyebilir. iOS'ta uygulamayı uygulama değiştiriciden zorla kapatmak sessiz background işlemlerini sınırlar; Android'de Ayarlar → Zorla durdur, FCM alımını yeniden açılana kadar engelleyebilir. Görünür `notification` içerikli FCM ile yalnızca sessiz `data` mesajları aynı davranmaz. Hatırlatmalar yalnızca cihazın en son senkronize ettiği plana göre gönderilir.

**Önemli:** GitHub kodunun güncellenmesi Firebase Functions'ı deploy etmez veya mağazalardaki uygulamaları otomatik güncellemez.
