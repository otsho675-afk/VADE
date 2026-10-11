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
      case "schedule":
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? Int,
              let epochMillis = args["epochMillis"] as? NSNumber,
              let title = args["title"] as? String,
              let body = args["body"] as? String else {
          result(FlutterError(code: "INVALID_REMINDER", message: "Missing reminder details.", details: nil))
          return
        }
        let interval = epochMillis.doubleValue / 1000.0 - Date().timeIntervalSince1970
        guard interval > 0 else {
          result(nil)
          return
        }
        self.addReminder(id: id, title: title, body: body,
                         interval: interval, result: result)
      case "showNow":
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? Int,
              let title = args["title"] as? String,
              let body = args["body"] as? String else {
          result(FlutterError(code: "INVALID_REMINDER", message: "Missing test notification details.", details: nil))
          return
        }
        self.addReminder(id: id, title: title, body: body,
                         interval: 1.0, result: result)
      case "pendingIds":
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
          let ids: [Int] = requests.compactMap { request in
            guard request.identifier.hasPrefix("vadesi-reminder-") else { return nil }
            return Int(request.identifier.replacingOccurrences(of: "vadesi-reminder-", with: ""))
          }
          DispatchQueue.main.async { result(ids) }
        }
      case "cancelIds":
        let args = call.arguments as? [String: Any]
        let ids = args?["ids"] as? [Int] ?? []
        let names = ids.map { "vadesi-reminder-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: names)
        result(nil)
      case "cancelAll":
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
          let names = requests
            .map { $0.identifier }
            .filter { $0.hasPrefix("vadesi-reminder-") }
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: names)
          DispatchQueue.main.async { result(nil) }
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

  // Native iOS local notifications: independent from the Flutter plugin's
  // permission-dependent initialization, and available after a TestFlight update.
  private func addReminder(id: Int, title: String, body: String,
                           interval: TimeInterval, result: @escaping FlutterResult) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: max(1.0, interval),
      repeats: false
    )
    let request = UNNotificationRequest(
      identifier: "vadesi-reminder-\(id)",
      content: content,
      trigger: trigger
    )
    UNUserNotificationCenter.current().add(request) { error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "SCHEDULE_FAILED",
                              message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  // Display our own test/reminder notifications even when the app is in front.
  // Other notifications remain handled by Flutter and third-party integrations.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.identifier.hasPrefix("vadesi-reminder-") {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      super.userNotificationCenter(
        center, willPresent: notification, withCompletionHandler: completionHandler
      )
    }
  }
}
