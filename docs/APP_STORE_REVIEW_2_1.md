# App Store Review — Guideline 2.1 (Information Needed)

Applies to **VADESİ 1.3.0 (build 11)**, built from the `main` branch with the default flags (`PREMIUM_ENABLED=false`). Check the exact build selected in App Store Connect before copying this response.

## REQUIRED — outside the repository

1. Use a **physical iPhone or iPad on the latest available iOS/iPadOS**, install the **same build submitted to review**, and make a screen recording starting from the app icon and first launch. Simulators, mockups and still images do not meet Apple's recording request.
2. Show: first-launch welcome → **Misafir olarak devam et** → dashboard → **+** create a manual installment/invoice → Ödemeler (search/mark paid) → Takvim → Raporlar → Ayarlar (notifications/backup) → Hesabım → registration and login → **Hesabımı sil**. Record deletion using a **throwaway account**. If you record deletion, create a separate working review account afterwards.
3. Upload/attach the video in the **App Store Connect Resolution Center** reply or provide a working, accessible recording link. The repository cannot generate genuine physical-device footage.
4. Create a dedicated **non-personal review email/password** in Firebase Authentication, verify login and account deletion. Place credentials **ONLY in private App Store Connect App Review Information → Sign-In Information / Notes**. Do NOT put passwords or credentials in GitHub or public documents.
5. Paste the reply below in **both** the Resolution Center reply and **App Review Information → Notes**. Confirm the listed services are actually operational in the submitted build. Ensure actual-app screenshots and working support/privacy URLs are set.
6. Check **TestFlight on physical iPhone and iPad**: clean install, no-network guest access, form save/edit/delete, notification permission, file backup/restore, registering/signing in/deleting account, no crashes or overflow. A successful CI build is not a substitute.

## English response — paste after filling only the placeholders

Hello App Review Team,

Thank you for reviewing VADESİ. Please find the requested information below.

**1. Physical-device screen recording**
We have attached a screen recording captured on a physical [DEVICE MODEL] running [iOS/iPadOS VERSION], using the build submitted for review: [VERSION / BUILD]. The recording begins with launching the app and demonstrates guest access, creating a payment, marking it paid, the calendar, reports, reminders, the optional registration and login flow, and account deletion. [ATTACH VIDEO OR INSERT ACCESSIBLE RECORDING LINK.]

**2. Purpose and target audience**
VADESİ is a Turkish-language personal payment-deadline organizer intended for individuals who need to keep track of installments, recurring bills, subscriptions, debts and receivables. Users manually enter amounts and dates, review upcoming and overdue items, and optionally enable reminders. It does **not** initiate bank transfers, pay bills, connect to banks or offer credit.

**3. Access and instructions**
No account or demo credentials are required to use the main payment-tracking features. On the welcome screen tap **“Misafir olarak devam et”** (Continue as guest). Tap **“+”** to create an item, then open **“Ödemeler”** (Payments), **“Takvim”** (Calendar), **“Raporlar”** (Reports) or **“Ayarlar”** (Settings). A sample entry can be made manually: title “Telefon taksiti”, amount 599 TRY, installment count 3, due date seven days from today. No sample file is necessary.

Account features are optional and can be accessed using the profile icon or **Ayarlar → Hesabım**. **“Üye ol”** is registration and **“Giriş yap”** is login. **“Şifremi unuttum”** sends a password reset email. After login, **Hesabım → Hesabımı sil** deletes the account after password reauthentication; local device payment records remain separate. Account deletion can also be requested at https://vade-b46fb.web.app/delete.html.

Review login (for account-only flows): [ENTER TEST EMAIL AND PASSWORD IN APP STORE CONNECT PRIVATE SIGN-IN FIELDS, NOT IN PUBLIC GITHUB]. A separate disposable account should be used for demonstrating account deletion so that reviewer credentials stay valid.

**4. External services**
- Google Firebase Authentication: optional email/password accounts.
- Google Cloud Firestore: account profile information and optional account-based backup data if enabled.
- Firebase Realtime Database: account presence/online status for signed-in users.
- OneSignal: optional app announcement push notifications if the user enables them; payment deadline reminders are scheduled locally on the device.
- Firebase Hosting: hosts our privacy policy, terms and account deletion pages.
- Device SQLite/local storage: personal payment tracking; there is no bank-data provider.
- Apple in-app purchase code exists in the project but Premium/in-app subscriptions are **disabled in the default submitted build**; no paid features are available in this configuration.

**5. Regional availability**
We do not intentionally restrict features by geographic region. The app interface is currently in Turkish, money values are formatted in Turkish lira, and its scheduled reminders use the Europe/Istanbul time zone; these localization limitations apply regardless of the user's country. The app is mainly designed for users in Türkiye.

**6. Regulated industry and third-party material**
VADESİ is a personal record-keeping/reminder tool, not a payment processor, bank, credit provider or regulated financial service. It does not execute financial transactions or display licensed/protected third-party media. No special financial authorization or third-party content license is applicable to the current features. Users' private notes and payment records are not published to other users, and there is no public user-generated-content feed.

**Privacy, support and deletion**
Privacy policy: https://vade-b46fb.web.app/privacy.html
Terms: https://vade-b46fb.web.app/terms.html
Account deletion: https://vade-b46fb.web.app/delete.html
Support: otsho675@gmail.com

Please let us know if you need any additional details.

Kind regards,
VADESİ Support

---

Important: Do **not** claim the recording was attached, physical-device QA was completed, a demo account exists, or Premium is disabled unless these are actually true for the submitted build. Do not submit this template with bracketed placeholders.
