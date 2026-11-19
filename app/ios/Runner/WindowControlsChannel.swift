import Flutter
import UIKit

// The iOS side of `app.cuadrante/window_controls` (Dart:
// lib/core/platform/window_controls.dart).
//
// In Windowed Apps mode, iPadOS 26 draws the window controls (the three dots)
// over the top-left corner of the app's window and expects the content to
// keep clear of them. UIKit apps do that through the corner-adapting layout
// regions; `safeAreaInsets`, which is all Flutter reads, does not include
// them. This channel reads the region.
//
// Dart -> Swift:
// - `topInset`: the distance in points from the top of the window to the
//   bottom of the window controls, or 0 when there are none (an iPhone, Full
//   Screen Apps or Stage Manager without them, a window already below them,
//   iPadOS before 26). It is only ever the room the controls need beyond the
//   normal top safe area. The first call also starts the watch below.
//
// Swift -> Dart:
// - `topInset` (same number) whenever it changes: moving or resizing the
//   window, or changing the multitasking mode, changes the region without the
//   Flutter view's own metrics having to change.
final class WindowControlsChannel: NSObject {
  static let shared = WindowControlsChannel()
  static let channelName = "app.cuadrante/window_controls"

  private var channel: FlutterMethodChannel?
  private var probe: AnyObject?
  private var last: Double = 0

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "topInset":
        self?.startWatching()
        let now = self?.topInset() ?? 0
        self?.last = now
        result(now)
      default: result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func hostView() -> UIView? {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      if let view = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController?.view {
        return view
      }
    }
    return nil
  }

  private func topInset() -> Double {
    guard UIDevice.current.userInterfaceIdiom == .pad,
      #available(iOS 26.0, *), let view = hostView()
    else { return 0 }
    // Safe area adapted vertically: its top edge sits below the controls.
    let adapted = view.directionalEdgeInsets(for: .safeArea(cornerAdaptation: .vertical)).top
    return adapted > view.safeAreaInsets.top ? Double(adapted) : 0
  }

  /// Adds an invisible view that spans the Flutter view except for the part
  /// above the vertically adapted safe-area guide: only its top edge is pinned
  /// to the guide, the others to the view. When the guide's top changes (the
  /// window is moved or resized, the mode changes) the probe's frame changes
  /// and UIKit lays it out again, which is the notification this region does
  /// not have of its own. Everything runs on the main thread, and publishing
  /// the same number twice does nothing, so a layout pass cannot loop.
  private func startWatching() {
    guard probe == nil, UIDevice.current.userInterfaceIdiom == .pad,
      #available(iOS 26.0, *), let host = hostView()
    else { return }
    let view = RegionProbe()
    view.onLayout = { [weak self] in self?.publish() }
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isUserInteractionEnabled = false
    view.isAccessibilityElement = false
    view.accessibilityElementsHidden = true
    view.alpha = 0
    host.addSubview(view)
    let guide = host.layoutGuide(for: .safeArea(cornerAdaptation: .vertical))
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: guide.topAnchor),
      view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
    ])
    probe = view
  }

  /// Sends the inset to Dart when, and only when, it changed.
  private func publish() {
    let now = topInset()
    guard now != last else { return }
    last = now
    channel?.invokeMethod("topInset", arguments: now)
  }
}

/// An invisible view whose layout pass is the signal that the guide moved.
private final class RegionProbe: UIView {
  var onLayout: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }
}
