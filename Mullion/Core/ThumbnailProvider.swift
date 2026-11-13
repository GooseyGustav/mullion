import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Supplies still images of window content.
///
/// The protocol exposes a synchronous `cached` read in addition to the async capture
/// so the panel can paint the previous presentation's frames on the same run-loop
/// turn that ⌥⇥ is handled.
protocol ThumbnailProvider {
    /// Whatever is cached for `ids`, regardless of age. Never blocks on the system.
    func cached(_ ids: [CGWindowID]) -> [CGWindowID: CGImage]

    /// Captures only windows whose cached image is missing or older than
    /// `freshness`, and returns every image available afterwards (cached or new).
    func capture(_ windows: [WindowItem], maximumWidth: CGFloat) async -> [CGWindowID: CGImage]
}

/// ScreenCaptureKit implementation with two small caches.
///
/// Efficiency model — this is deliberately **event-driven, not background-driven**:
/// - No timers, no polling, no `SCStream`. Idle cost is zero.
/// - `cached` makes a re-open within `freshness` free: no capture at all.
/// - `capture` skips windows whose image is still fresh.
/// - The `SCShareableContent` enumeration (the slowest call, ~100–300 ms) is reused
///   for `contentFreshness` seconds instead of repeating on every open.
/// - The image cache is capped at `imageLimit` entries of at most 402 px wide, so
///   memory stays in the low tens of megabytes at worst.
final class ScreenCaptureThumbnailProvider: ThumbnailProvider {
    private struct Entry {
        let image: CGImage
        let date: Date
    }

    /// Re-opening within this window performs no capture: cached frames are shown.
    /// Three seconds is long enough to cover the "switch, change your mind, switch
    /// back" pattern without ever showing a frame that looks out of date.
    static let freshness: TimeInterval = 3.0
    private static let contentFreshness: TimeInterval = 2.0
    private let imageLimit = 32
    /// Large enough to overlap most of a screen's windows in one pass, small enough
    /// that the first image still lands quickly.
    private let batchSize = 12

    private let lock = NSLock()
    private var entries: [CGWindowID: Entry] = [:]
    private var content: (value: SCShareableContent, date: Date)?

    // MARK: - ThumbnailProvider

    func cached(_ ids: [CGWindowID]) -> [CGWindowID: CGImage] {
        lock.lock()
        defer { lock.unlock() }
        var images: [CGWindowID: CGImage] = [:]
        for id in ids {
            if let entry = entries[id] { images[id] = entry.image }
        }
        return images
    }

    func capture(_ windows: [WindowItem], maximumWidth: CGFloat) async -> [CGWindowID: CGImage] {
        guard !windows.isEmpty else { return [:] }

        let now = Date()
        let stale = windows.filter { window in
            lock.lock()
            defer { lock.unlock() }
            guard let entry = entries[window.id] else { return true }
            return now.timeIntervalSince(entry.date) > Self.freshness
        }
        guard !stale.isEmpty else {
            return cached(windows.map(\.id))
        }

        let shareable: SCShareableContent
        do {
            shareable = try await shareableContent()
        } catch {
            AppLog.write("SCShareableContent failed: \(error.localizedDescription)")
            if !Permissions.hasScreenRecording {
                Permissions.requestScreenRecording()
            }
            return cached(windows.map(\.id))
        }

        var shareableByID = Self.index(shareable)
        if stale.contains(where: { shareableByID[$0.id] == nil }) {
            // The cached enumeration predates a window that is now on screen. Asking
            // again is worth 100–300 ms: otherwise that tile silently keeps its icon
            // placeholder even though the window is capturable.
            if let refreshed = try? await shareableContent(forceRefresh: true) {
                shareableByID = Self.index(refreshed)
            }
        }

        let started = Date()
        var capturedCount = 0
        for batch in stale.chunked(into: batchSize) {
            let captured = await withTaskGroup(of: (CGWindowID, CGImage?).self) { group in
                for window in batch {
                    guard let shareable = shareableByID[window.id] else { continue }
                    group.addTask {
                        (window.id, await Self.capture(shareable, maximumWidth: maximumWidth))
                    }
                }
                var result: [CGWindowID: CGImage] = [:]
                for await (id, image) in group {
                    if let image { result[id] = image }
                }
                return result
            }
            capturedCount += captured.count
            store(captured, at: now)
        }

        AppLog.write(String(format: "captured %d/%d in %.0f ms",
                            capturedCount, stale.count,
                            Date().timeIntervalSince(started) * 1000))
        return cached(windows.map(\.id))
    }

    // MARK: - Caches

    private func store(_ images: [CGWindowID: CGImage], at date: Date) {
        guard !images.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        for (id, image) in images {
            entries[id] = Entry(image: image, date: date)
        }
        // Bound memory: drop the oldest entries when over the limit.
        if entries.count > imageLimit {
            let overflow = entries.count - imageLimit
            let oldest = entries.sorted { $0.value.date < $1.value.date }.prefix(overflow)
            for (id, _) in oldest { entries.removeValue(forKey: id) }
        }
    }

    private static func index(_ content: SCShareableContent) -> [CGWindowID: SCWindow] {
        var windows: [CGWindowID: SCWindow] = [:]
        for window in content.windows {
            windows[window.windowID] = window
        }
        return windows
    }

    private func shareableContent(forceRefresh: Bool = false) async throws -> SCShareableContent {
        lock.lock()
        let cachedContent = content
        lock.unlock()

        if !forceRefresh,
           let cachedContent,
           Date().timeIntervalSince(cachedContent.date) < Self.contentFreshness {
            return cachedContent.value
        }

        let fresh = try await SCShareableContent.excludingDesktopWindows(false,
                                                                        onScreenWindowsOnly: true)
        lock.lock()
        content = (fresh, Date())
        lock.unlock()
        return fresh
    }

    // MARK: - Capture

    private static func capture(_ window: SCWindow, maximumWidth: CGFloat) async -> CGImage? {
        let sourceWidth = max(window.frame.width, 1)
        let scale = min(1, maximumWidth / sourceWidth)
        let width = max(2, Int((sourceWidth * scale).rounded(.down)))
        let height = max(2, Int((window.frame.height * scale).rounded(.down)))

        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true

        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                      configuration: configuration) else {
            return nil
        }
        return trimmingWindowEdge(image)
    }

    /// Removes the window server's own 1 pt outline from a capture.
    ///
    /// The outline is part of the window image, not something Mullion draws, so
    /// ScreenCaptureKit cannot switch it off. Cropping the outer 2 px (at capture
    /// scale) is the only way to get a genuinely borderless preview; it eats a sliver
    /// of window chrome, never content. Rounded corners are masked by the cell, so no
    /// corner artifacts survive the crop.
    private static func trimmingWindowEdge(_ image: CGImage) -> CGImage {
        let inset = 2
        guard image.width > inset * 4, image.height > inset * 4 else { return image }
        let rect = CGRect(x: inset, y: inset,
                          width: image.width - inset * 2,
                          height: image.height - inset * 2)
        return image.cropping(to: rect) ?? image
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
