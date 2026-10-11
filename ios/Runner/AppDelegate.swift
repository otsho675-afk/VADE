import UserNotifications
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // With Flutter's UIScene lifecycle, channels must use the implicit engine.
    let channel = FlutterMethodChannel(
      name: "vadesi/notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    notificationChannel = channel
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "requestPermission":
        // Explicit native request ensures iOS gets a chance to show its system
        // prompt, even when a notification plugin reports an ambiguous false.
        UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .badge, .sound]
        ) { granted, error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "NOTIFICATION_PERMISSION",
                                  message: error.localizedDescription, details: nil))
            } else {
              result(granted)
            }
          }
        }
      case "authorizationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .authorized: status = "authorized"
          case .provisional: status = "provisional"
          case .denied: status = "denied"
          case .notDetermined: status = "notDetermined"
          @unknown default: status = "unknown"
          }
          DispatchQueue.main.async { result(status) }
        }
      case "openSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
