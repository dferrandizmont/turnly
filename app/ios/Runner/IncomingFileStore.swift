import Foundation

// File handling for «Abrir un .turnly desde otra app» (docs/copia-de-seguridad.md,
// "Abrir un .turnly desde otra app (iOS)"). Foundation only, so it can be tested
// without UIKit: where the copy goes, the 137 MiB cap, and the cleaning of
// `Documents/Inbox`.

final class IncomingFileStore {
  /// `BackupCodec.maxImportBytes` (137 MiB). Keep equal to the Dart constant.
  static let maxBytes = 143_654_912
  static let chunkBytes = 64 * 1024
  /// Folder name and file suffix the Dart side requires (`isIncomingTempPath`).
  static let incomingDirName = "incoming"
  static let incomingPrefix = "incoming-"
  static let incomingSuffix = ".turnly"

  enum CopyOutcome: Equatable {
    case saved(URL)
    case tooLarge
    case unreadable
  }

  private let documents: URL
  private let caches: URL
  private let maxBytes: Int
  private let chunkBytes: Int

  /// The sandbox folders are passed in so tests can use a temporary one.
  init(
    documentsDirectory: URL,
    cachesDirectory: URL,
    maxBytes: Int = IncomingFileStore.maxBytes,
    chunkBytes: Int = IncomingFileStore.chunkBytes
  ) {
    self.documents = documentsDirectory
    self.caches = cachesDirectory
    self.maxBytes = maxBytes
    self.chunkBytes = chunkBytes
  }

  static func forApp() -> IncomingFileStore? {
    let fm = FileManager.default
    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
      let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    return IncomingFileStore(documentsDirectory: docs, cachesDirectory: caches)
  }

  // MARK: - Documents/Inbox

  /// `<sandbox>/Documents/Inbox` as a resolved path, or `nil` when `Inbox` is
  /// not exactly that folder (for instance a symlink that leads elsewhere):
  /// then nothing is ever deleted.
  private func inboxPath() -> String? {
    let docs = documents.standardizedFileURL.resolvingSymlinksInPath().path
    let expected = docs + "/Inbox"
    let inbox = documents.appendingPathComponent("Inbox", isDirectory: true)
      .standardizedFileURL.resolvingSymlinksInPath().path
    return inbox == expected ? expected : nil
  }

  private func resolvedPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }

  /// Whether `url` is a file inside `<sandbox>/Documents/Inbox/`: exact prefix
  /// after `standardizedFileURL.resolvingSymlinksInPath()`. The folder itself is
  /// not "inside".
  func isInInbox(_ url: URL) -> Bool {
    guard url.isFileURL, let inbox = inboxPath() else { return false }
    let path = resolvedPath(url)
    return path.hasPrefix(inbox + "/") && path.count > inbox.count + 1
  }

  /// Deletes `url` only if it is inside `Documents/Inbox/`. A file opened in
  /// place (the user's original in Files, iCloud Drive...) is never touched.
  func deleteIfInInbox(_ url: URL) {
    guard isInInbox(url) else { return }
    try? FileManager.default.removeItem(at: url)
  }

  /// Empties `Documents/Inbox` (the app uses it for nothing else), except the
  /// file `keeping` points to (a newer URL still waiting to be read). Only
  /// entries whose resolved path is inside `Inbox/` are removed.
  func emptyInbox(keeping: [URL] = []) {
    guard let inbox = inboxPath() else { return }
    let fm = FileManager.default
    let inboxURL = URL(fileURLWithPath: inbox, isDirectory: true)
    guard
      let children = try? fm.contentsOfDirectory(
        at: inboxURL, includingPropertiesForKeys: nil, options: [])
    else { return }
    let keepPaths = keeping.map(resolvedPath)
    for child in children {
      let path = resolvedPath(child)
      guard path.hasPrefix(inbox + "/") else { continue }
      if keepPaths.contains(where: { $0 == path || $0.hasPrefix(path + "/") }) { continue }
      try? fm.removeItem(at: child)
    }
  }

  // MARK: - Library/Caches/incoming

  private var incomingDir: URL {
    caches.appendingPathComponent(IncomingFileStore.incomingDirName, isDirectory: true)
  }

  /// Streams `source` (already inside a coordinated read) to a new
  /// `<Caches>/incoming/incoming-<uuid>.turnly` in 64 KiB chunks. Looks at the
  /// size before reading a byte and counts what it copies, so the cap holds
  /// even if the file grows. On any failure, or past the cap, what was copied is
  /// deleted. The file is never held in memory.
  func copyToIncoming(from source: URL, isCancelled: () -> Bool = { false }) -> CopyOutcome {
    let fm = FileManager.default
    guard
      let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
      values.isRegularFile == true
    else { return .unreadable }
    if let size = values.fileSize, size > maxBytes { return .tooLarge }
    do {
      try fm.createDirectory(at: incomingDir, withIntermediateDirectories: true)
    } catch {
      return .unreadable
    }
    let target = incomingDir.appendingPathComponent(
      IncomingFileStore.incomingPrefix + UUID().uuidString + IncomingFileStore.incomingSuffix)
    // Readable only while the device is unlocked: this is a copy of the user's data.
    guard
      fm.createFile(
        atPath: target.path, contents: nil, attributes: [.protectionKey: FileProtectionType.complete])
    else { return .unreadable }
    do {
      let input = try FileHandle(forReadingFrom: source)
      let output = try FileHandle(forWritingTo: target)
      defer {
        try? input.close()
        try? output.close()
      }
      var total = 0
      while true {
        if isCancelled() { throw CocoaError(.userCancelled) }
        let chunk = try autoreleasepool { try input.read(upToCount: chunkBytes) }
        guard let chunk, !chunk.isEmpty else { break }
        total += chunk.count
        if total > maxBytes {
          try? fm.removeItem(at: target)
          return .tooLarge
        }
        try output.write(contentsOf: chunk)
      }
      try output.synchronize()
      return .saved(target)
    } catch {
      try? fm.removeItem(at: target)
      return .unreadable
    }
  }

  /// Housekeeping at start: copies in `incoming/` that Dart never took (the app
  /// died between the copy and the read) and are older than `maxAge`.
  func sweepStaleIncoming(maxAge: TimeInterval = 3600, now: Date = Date()) {
    let fm = FileManager.default
    guard
      let children = try? fm.contentsOfDirectory(
        at: incomingDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
    else { return }
    for file in children {
      let name = file.lastPathComponent
      guard name.hasPrefix(IncomingFileStore.incomingPrefix),
        name.hasSuffix(IncomingFileStore.incomingSuffix)
      else { continue }
      let modified =
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      if let modified, now.timeIntervalSince(modified) < maxAge { continue }
      try? fm.removeItem(at: file)
    }
  }
}
