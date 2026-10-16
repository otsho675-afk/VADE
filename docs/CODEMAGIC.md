# Codemagic

Branch: `codex/vadesi-platform-upgrade`. Read `codemagic.yaml` from this branch.

`ios-simulator`: does not require an Apple signing key. Builds the real iOS application and captures its welcome screen on an available iPhone simulator. Download `build/ios-screenshots/01-welcome.png` and inspect it before store submission. The device metadata is included; a fallback device may have different dimensions. This does not produce an installable App Store IPA.

`ios-app-store`: produces a signed IPA after Apple Distribution certificate and matching App Store provisioning profile have been added in Codemagic Team settings → Code signing identities. The profile must match `com.vadesi.vadesi` and its Push Notifications/App Groups entitlements. Register and assign `group.com.vadesi.vadesi.onesignal` in Apple Developer. API integration can fetch the signing identities, but the APNs .p8 key is not an App Store Connect API key.

The signed workflow is manual and does not automatically submit for review. Download the IPA after a successful build, or configure Codemagic App Store Connect publishing with the team's API integration. No Apple private keys or Android upload keystores belong in Git.

The simulator workflow has a push trigger. It runs automatically only if the Codemagic repository webhook is connected and enabled. Otherwise choose Start new build → this branch → ios-simulator. A Git push alone does not prove a build started.

Current source version: 1.4.0+17. Before reusing an already uploaded build number, increment pubspec.yaml.

Outstanding: complete and verify OneSignal iOS Notification Service Extension setup, Apple signing, real-device notification delivery, and store privacy declarations. A successful simulator build alone does not certify release readiness.
