# VADESİ 1.2.0 — yayın hazırlığı

## Kararlaştırılan ücretsiz çalışma şekli
- Firebase Authentication, Firestore profil ve Realtime Database çevrimiçi durum.
- Telefon üzerinde zamanlanan vade hatırlatmaları.
- Kullanıcının ayrıca izin verdiği OneSignal duyuruları; gönderim OneSignal panelinden.
- Blaze/Cloud Functions açılmadı. Premium satış varsayılan olarak kapalı.

## Tamamlananlar
- Android Firebase varsayılan istemci yapılandırması.
- iOS Firebase uygulaması oluşturuldu ve istemci ayarları eklendi.
- Android release için özel upload anahtarı oluşturuldu; debug anahtarıyla release derlemek kaldırıldı.
- Android tam saat izni seçeneği ve izin yoksa yaklaşık zamanlama.
- Kayıt/giriş, vade uyarıları ve tekrar engelleme testleri.
- Sunucu fonksiyonu olmadan hesap silme, sahiplik kuralları ve canlı Firebase testi.
- Gizlilik, kullanım koşulları, hesap silme ve yönetici sayfaları.

## Canlı bağlantılar
- Yönetici: https://vade-b46fb.web.app
- Gizlilik: https://vade-b46fb.web.app/privacy.html
- Koşullar: https://vade-b46fb.web.app/terms.html
- Hesap silme: https://vade-b46fb.web.app/delete.html
- Destek: otsho675@gmail.com

## Yayından önce kalanlar — tamamlandı olarak kabul edilmemeli
- Google Play hesabının doğrulama ve üretim/kapalı test erişimini konsoldan kontrol etmek.
- App Store Connect uygulama kaydı, Apple Developer Team, dağıtım sertifikası ve provisioning.
- OneSignal Google FCM hizmet hesabı bağlantısını ve iOS APNs .p8 bağlantısını doğrulamak.
- iOS Notification Service Extension ve App Group ayarlarını Xcode/macOS üzerinde tamamlamak.
- iOS release derlemesi ve fiziksel iPhone bildirim testi.
- Fiziksel Android'de release paketiyle izin, tam saat, yeniden başlatma ve arka plan teslimatı testi.
- Mağaza ekran görüntüleri, veri güvenliği/uygulama gizliliği beyanları, yaş derecelendirmesi ve mağaza incelemesi.
- OneSignal gerçek cihaz test duyurusu; gönderim için ayrıca test hedefi seçilmeli.

## İmzalama anahtarı
android/vadesi-upload.jks ve android/key.properties yereldedir, Git tarafından yok sayılır.
Bu iki dosyayı güvenli ve özel bir yerde yedekleyin. Kaynak ZIP'ine veya herkese açık depoya eklemeyin.
AAB mağazaya gönderim içindir; telefona APK gibi kurulmaz.
