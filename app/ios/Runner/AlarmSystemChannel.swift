import Flutter
import UIKit
import UserNotifications

// The iOS side of `app.cuadrante/alarm_system` (Android: AlarmSystemChannel.kt;
// Dart: lib/features/alarms/data/alarm_system.dart, docs/alarmas.md).
//
// Dart -> Swift:
// - `notificationsBlocked`: true when the notifications are denied. iOS shows
//   its prompt only once, so after a «Don't Allow» asking again does nothing
//   and the only way out is the app's notification settings (H-T11-1).
// - `markNotificationsAsked`: nothing to do on iOS (the system tells
//   "never asked" from "denied" by itself).
// - `openNotificationSettings`: opens the app's notification settings (iOS 16+)
//   or the app's settings page. Answers whether a screen was asked to open.
//
// Swift -> Dart:
// - `clockChanged` with "timezone" or "time" when the time zone or the clock
//   changes while the app is alive (H-T11-4), so the alarms are planned again.
final class AlarmSystemChannel: NSObject {
  static let shared = AlarmSystemChannel()
  static let channelName = "app.cuadrante/alarm_system"

  private var channel: FlutterMethodChannel?
  private var observers: [NSObjectProtocol] = []

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
    observeClock()
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "notificationsBlocked":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async { result(settings.authorizationStatus == .denied) }
      }
    case "markNotificationsAsked":
      result(nil)
    case "openNotificationSettings":
      let string: String
      if #available(iOS 16.0, *) {
        string = UIApplication.openNotificationSettingsURLString
      } else {
        string = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: string), UIApplication.shared.canOpenURL(url) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func observeClock() {
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    observers.append(center.addObserver(
      forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
    ) { [weak self] _ in
      self?.channel?.invokeMethod("clockChanged", arguments: "timezone")
    })
    observers.append(center.addObserver(
      forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.channel?.invokeMethod("clockChanged", arguments: "time")
    })
  }
}
