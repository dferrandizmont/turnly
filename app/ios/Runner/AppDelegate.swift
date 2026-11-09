import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: show alarms while the app is open.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // «Abrir un .turnly desde otra app» (docs/mac-ios.md 4.3, step 4): before
    // the plugins, because Flutter stops dispatching a scene event at the first
    // delegate that claims it (this one never does).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TurnlyIncomingBackup") {
      registrar.addSceneDelegate(IncomingBackupChannel.shared)
      IncomingBackupChannel.shared.register(with: registrar)
    }
    // Alarms: notifications denied for good, their settings screen, clock changes.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TurnlyAlarmSystem") {
      AlarmSystemChannel.shared.register(with: registrar)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // flutter_local_notifications: the engine that runs «Posponer» with the app
    // closed needs the plugins too (docs/mac-ios.md 4.2, step 4).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
  }

  // The plugin starts the Dart isolate of «Posponer» and answers iOS at once,
  // so with the app closed iOS suspends it before the snoozed alarm is
  // scheduled. A background task keeps it awake long enough for that.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let application = UIApplication.shared
    var task = UIBackgroundTaskIdentifier.invalid
    let finish = {
      guard task != .invalid else { return }
      application.endBackgroundTask(task)
      task = .invalid
    }
    task = application.beginBackgroundTask(withName: "cuadrante.alarm.action", expirationHandler: finish)
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: finish)
  }
}
