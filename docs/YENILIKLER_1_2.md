# VADESİ 1.2

- İlk açılışta logolu karşılama, Üye ol, Giriş yap ve misafir devamı.
- Ana sayfa ve hesap bölümünde her zaman görünür üyelik girişleri.
- E-posta/şifre doğrulama, şifreyi gösterme, şifre tekrar kontrolü, otomatik doldurma ve şifre yenileme.
- Kayıt için uygulama içi hesap verileri bilgilendirmesi ve onay. Kayıt artık boş politika URL'si nedeniyle gizlice kapatılmaz. Yayından önce gerçek gizlilik/kullanım koşulları adreslerini tanımlayın.
- Ödeme ekleme/düzenleme ve takvimde gün–ay–yıl çarkı. Hatırlatma saati de kaydırılarak seçilir.
- Para için sayısal klavye, taksit için yalnızca rakam, IBAN için büyük harf/gruplama; klavye üstünde önceki/sonraki/Bitti.
- Yeşil tonlarda yeni finans özeti, karşılama kartları, daha büyük düğmeler ve yuvarlak kartlar.
- Mevcut VADESİ logosu karşılama/hesap/üst çubukta; Android adaptive ikon ve web ikonları kurulumda üretilir.

## Windows'ta güncelle

Proje klasöründe önce yerel değişikliklerini kontrol et: `git status`.
Yerel kod değişikliklerin varsa yedekle/commit et; ardından `git pull --ff-only`.

PowerShell'de:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\scripts\baslat.ps1
```

Baslat betiği var olan config/firebase.android.json dosyasını korur. Dosya yoksa proje kökündeki google-services.json Android istemci ayarlarından oluşturur. Hizmet hesabı özel anahtarı kullanmaz.
Firebase vade-b46fb projesinin veritabanı ve OneSignal App ID'si desteklenir. Ayar dosyası olmadan hesap sunucusuna bağlanılmaz; karşılama ekranında misafir kullanım açık kalır.

Telefon simgesi eski görünüyorsa önce uygulamayı tamamen kapatıp yeni APK'yı aynı paket kimliğiyle yükleyin. Verileri korumak için uygulamayı kaldırmanız gerekmez.
Mağaza imzaları, gerçek Firebase oturumu ve push teslimatı kendi hesap/cihazınızla ayrıca doğrulanmalıdır.
