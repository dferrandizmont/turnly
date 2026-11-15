import Flutter
import UIKit

// «Abrir un .turnly desde otra app (R4)»: the iOS side of the channel
// `app.cuadrante/backup` (docs/copia-de-seguridad.md, "Abrir un .turnly desde
// otra app (iOS)"; docs/mac-ios.md 4.3 step 4).
//
// Only `hasPending`, `readPending`, `discardPending` (Dart -> Swift) and
// `incomingAvailable` (Swift -> Dart) exist. `setPreviewProtection` and
// `systemBackupState` answer FlutterMethodNotImplemented (Dart treats the
// MissingPluginException as "nothing to do").
//
// Security rules:
// - The only source of a URL is the system, through the scene callbacks below.
//   Dart never sends a path, and no method takes an argument.
// - A URL is only remembered (plus startAccessingSecurityScopedResource) until
//   Dart takes it with `readPending` or forgets it with `discardPending`.
// - `readPending` hands over the URL it reads: it is read once, and the access
//   it holds is its own, so a newer URL never releases it.
// - Nothing is restored here: Dart validates the bytes and the user confirms in
//   the restore preview. `sender` is never sent (iOS does not say who sent it).
//
// Hooked as a FlutterSceneLifeCycleDelegate (like Mochila's SharePayloadCleaner)
// and registered before the plugins: Flutter stops dispatching a scene event at
// the first delegate that claims it, so this one never claims an event
// (home_widget, which only wants `homeWidget` URLs, keeps working).
final class IncomingBackupChannel: NSObject, FlutterSceneLifeCycleDelegate {
  static let shared = IncomingBackupChannel()

  static let channelName = "app.cuadrante/backup"
  /// Deadline of one `readPending` (a file that is not downloaded in time is `unreadable`).
  private static let readDeadline: TimeInterval = 60

  private let store = IncomingFileStore.forApp()
  private var channel: FlutterMethodChannel?

  // Main thread only.
  private var pendingURL: URL?
  private var pendingHasAccess = false
  /// URLs being read right now (a list, so the same URL twice counts twice).
  /// Their Inbox copies are never swept until their read has really ended.
  private var readingURLs: [URL] = []

  /// What `emptyInbox` must leave alone: the pending URL and every URL in a read.
  private var keptURLs: [URL] { readingURLs + (pendingURL.map { [$0] } ?? []) }

  private let readQueue = DispatchQueue(
    label: "es.cuadrante.app.incoming-read", qos: .userInitiated)

  // MARK: - Registration

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: IncomingBackupChannel.channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasPending":
      result(pendingURL != nil)
    case "discardPending":
      forgetPending()
      result(nil)
    case "readPending":
      readPending(result)
    default:
      // setPreviewProtection, systemBackupState: not used on iOS.
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Scene events (URLs from the system)

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    // Cold start: nothing listens in Dart yet; BackupHost asks `hasPending`.
    if let url = connectionOptions?.urlContexts.lazy.map({ $0.url }).first(where: { $0.isFileURL }) {
      remember(url)
    }
    // Start-up housekeeping, after remembering the URL that launched the app
    // (it may be the very copy in Inbox): leftovers of a previous run go.
    store?.emptyInbox(keeping: keptURLs)
    store?.sweepStaleIncoming()
    // false: never claim the connection, so plugins after this one still get it.
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    if let url = URLContexts.lazy.map({ $0.url }).first(where: { $0.isFileURL }) {
      remember(url)
      // The app is running: tell Dart (a Dart that is not listening yet finds it with `hasPending`).
      channel?.invokeMethod("incomingAvailable", arguments: nil)
    }
    return false
  }

  // MARK: - Pending URL

  /// Remembers `url` (replacing the previous pending one, whose access is
  /// released). A URL that is being read is not pending any more, so it is
  /// never touched here.
  private func remember(_ url: URL) {
    if let old = pendingURL, old != url { releasePending(old) }
    if pendingURL == url { return }
    pendingHasAccess = url.startAccessingSecurityScopedResource()
    pendingURL = url
  }

  /// Stops the access of the pending URL and deletes its copy if it is in `Inbox`.
  private func releasePending(_ url: URL) {
    if pendingHasAccess { url.stopAccessingSecurityScopedResource() }
    store?.deleteIfInInbox(url)
    pendingHasAccess = false
    pendingURL = nil
  }

  private func forgetPending() {
    if let url = pendingURL { releasePending(url) }
    store?.emptyInbox(keeping: keptURLs)
  }

  // MARK: - readPending

  /// One read: its own URL and its own access, finished exactly once.
  private final class ReadJob {
    private let lock = NSLock()
    private var cancelled = false
    private var finished = false
    private var coordinator: NSFileCoordinator?

    var isCancelled: Bool {
      lock.lock()
      defer { lock.unlock() }
      return cancelled
    }

    func attach(_ coordinator: NSFileCoordinator) {
      lock.lock()
      self.coordinator = coordinator
      lock.unlock()
    }

    func cancel() {
      lock.lock()
      cancelled = true
      let coordinator = self.coordinator
      lock.unlock()
      coordinator?.cancel()
    }

    /// `true` for the first caller only: who replies to Dart.
    func claimReply() -> Bool {
      lock.lock()
      defer { lock.unlock() }
      if finished { return false }
      finished = true
      return true
    }
  }

  private func readPending(_ result: @escaping FlutterResult) {
    guard let url = pendingURL else {
      result(nil)
      return
    }
    guard let store else {
      forgetPending()
      result(["error": "unreadable"])
      return
    }
    // Once: from here on the URL belongs to this read, not to `pendingURL`.
    let hasAccess = pendingHasAccess
    pendingURL = nil
    pendingHasAccess = false

    let job = ReadJob()
    readingURLs.append(url)

    // The deadline is cancelled as soon as the read answers.
    let deadline = DispatchWorkItem {
      guard job.claimReply() else { return }
      job.cancel()
      store.emptyInbox(keeping: self.keptURLs)
      result(["error": "unreadable"])
    }

    // Called on the main thread, once.
    func reply(_ outcome: IncomingFileStore.CopyOutcome) {
      guard job.claimReply() else {
        // Timed out earlier: the answer is already sent; drop the late copy.
        if case .saved(let file) = outcome { try? FileManager.default.removeItem(at: file) }
        return
      }
      deadline.cancel()
      // Newer URLs waiting or being read are kept; everything else goes.
      store.emptyInbox(keeping: keptURLs)
      switch outcome {
      case .saved(let file): result(["path": file.path])
      case .tooLarge: result(["error": "tooLarge"])
      case .unreadable: result(["error": "unreadable"])
      }
    }

    DispatchQueue.main.asyncAfter(
      deadline: .now() + IncomingBackupChannel.readDeadline, execute: deadline)

    readQueue.async {
      var outcome = IncomingFileStore.CopyOutcome.unreadable
      let coordinator = NSFileCoordinator(filePresenter: nil)
      job.attach(coordinator)
      if !job.isCancelled {
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) {
          readURL in
          outcome = store.copyToIncoming(from: readURL, isCancelled: { job.isCancelled })
        }
      }
      // The access of this read ends with this read (and not before), whatever
      // happened to the URLs that arrived meanwhile.
      if hasAccess { url.stopAccessingSecurityScopedResource() }
      if job.isCancelled, case .saved(let file) = outcome {
        try? FileManager.default.removeItem(at: file)
        outcome = .unreadable
      }
      DispatchQueue.main.async {
        // The copy in Inbox (if it was one) has been read: it goes now.
        // (Unless the same file arrived again meanwhile and is pending now.)
        let arrivedAgain =
          (self.pendingURL.map { $0.standardizedFileURL == url.standardizedFileURL } ?? false)
          || self.readingURLs.filter { $0.standardizedFileURL == url.standardizedFileURL }.count > 1
        if !arrivedAgain { store.deleteIfInInbox(url) }
        // The read has really ended (even after a timeout): its URL is no longer protected.
        if let i = self.readingURLs.firstIndex(of: url) { self.readingURLs.remove(at: i) }
        reply(outcome)
      }
    }
  }
}
