import Foundation
import AppKit
import LicenseKit

enum MullionEntitlement: Equatable {
    case trial(daysRemaining: Int)
    case licensed
    case expired
    case revoked
    case needsActivation(message: String?)

    var canUseSwitcher: Bool {
        switch self {
        case .trial(let d): return d > 0
        case .licensed: return true
        case .expired, .revoked, .needsActivation: return false
        }
    }
}

/// Coordinates trial, activation, refresh, and entitlement for Mullion.
///
/// Production direct-download licensing: https://api.asifthatworks.com
@MainActor
final class MullionLicense: ObservableObject {
    static let shared = MullionLicense()

    private let trialDays = 14
    private let trialService = "com.kyanhpham.mullion.trial"
    private let trialAccount = "trial_start"
    private let supportFilename = "trial-start.txt"

    private let configuration: LicenseConfiguration
    private let manager: LicenseManager

    @Published private(set) var entitlement: MullionEntitlement = .trial(daysRemaining: 14)
    @Published private(set) var lastError: String?

    private var refreshTask: Task<Void, Never>?

    private init() {
        let baseURL = URL(string: "https://api.asifthatworks.com")!
        let publicKey = Data(base64URLEncoded: "HLmuY4Pcli5XDVFTwZOe5II4ouW8bNIIZMPaU5dHaO0")!
        self.configuration = LicenseConfiguration(
            baseURL: baseURL,
            productID: "mullion",
            keyPrefix: "MULL",
            appMajorVersion: 1,
            publicKeys: ["mull-2026-01": publicKey],
            bundleID: "com.kyanhpham.mullion"
        )
        // LicenseManager init can throw only on bad public key data; key is valid.
        self.manager = try! LicenseManager(configuration: configuration)
        ensureTrialStarted()
        Task { await reevaluate() }
    }

    func reevaluate() async {
        // Prefer a valid license; otherwise fall back to trial.
        let status = await manager.currentEntitlement()
        switch status {
        case .active:
            entitlement = .licensed
            lastError = nil
            return
        case .revoked:
            entitlement = .revoked
            return
        case .expired:
            // Could be expired subscription/token; check trial as fallback only if never licensed?
            // For one-time Mullion, server-side expired means revoked-like; treat as needs activation.
            entitlement = .needsActivation(message: "Your license has expired.")
            return
        case .invalid(let msg):
            lastError = msg
        case .unlicensed:
            break
        case .trial:
            break
        }
        let days = trialDaysRemaining()
        if days > 0 {
            entitlement = .trial(daysRemaining: days)
        } else if case .needsActivation = entitlement {
            // keep message
        } else {
            entitlement = .expired
        }
    }

    func refreshInBackground() {
        refreshTask?.cancel()
        refreshTask = Task {
            _ = await manager.refresh()
            await reevaluate()
        }
    }

    func activate(key: String) async {
        do {
            let status = try await manager.activate(key: key)
            if case .active = status {
                entitlement = .licensed
                lastError = nil
            } else {
                await reevaluate()
            }
        } catch {
            lastError = error.localizedDescription
            await reevaluate()
        }
    }

    func deactivate() async {
        do {
            try await manager.deactivate()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await reevaluate()
    }

    func handle(url: URL) {
        guard let link = LicenseDeepLink.parse(url, scheme: "mullion") else { return }
        switch link {
        case .activate(let key):
            Task { await activate(key: key) }
        case .deactivate:
            Task { await deactivate() }
        case .open:
            NotificationCenter.default.post(name: .mullionShowLicenseWindow, object: nil)
        }
    }

    // MARK: - Trial

    private func trialDaysRemaining(now: Date = Date()) -> Int {
        guard let start = trialStartDate() else { return trialDays }
        let elapsed = now.timeIntervalSince(start)
        if elapsed < -24 * 60 * 60 {
            // Clock moved back significantly: don't extend trial; treat as started now-ish by returning 0.
            return 0
        }
        let remaining = trialDays - Int(floor(max(0, elapsed) / 86_400))
        return max(0, min(trialDays, remaining))
    }

    private func ensureTrialStarted() {
        if trialStartDate() == nil {
            let now = Date()
            saveTrialStart(now)
        }
    }

    private func trialStartDate() -> Date? {
        let keychain = readTrialStartFromKeychain()
        let file = readTrialStartFromFile()
        switch (keychain, file) {
        case let (k?, f?): return min(k, f)
        case let (k?, nil):
            writeTrialStartToFile(k)
            return k
        case let (nil, f?):
            writeTrialStartToKeychain(f)
            return f
        case (nil, nil):
            return nil
        }
    }

    private func saveTrialStart(_ date: Date) {
        if let existing = trialStartDate() {
            // Keep the earliest.
            if date < existing {
                writeTrialStartToKeychain(date)
                writeTrialStartToFile(date)
            }
            return
        }
        writeTrialStartToKeychain(date)
        writeTrialStartToFile(date)
    }

    private func readTrialStartFromKeychain() -> Date? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trialService,
            kSecAttrAccount as String: trialAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }

    private func writeTrialStartToKeychain(_ date: Date) {
        let data = Data(ISO8601DateFormatter().string(from: date).utf8)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trialService,
            kSecAttrAccount as String: trialAccount
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        if SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
        } else {
            var add = q; attrs.forEach { add[$0.key] = $0.value }
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private func supportFileURL() -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Mullion", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(supportFilename)
    }

    private func readTrialStartFromFile() -> Date? {
        guard let url = supportFileURL(), let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return ISO8601DateFormatter().date(from: s.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func writeTrialStartToFile(_ date: Date) {
        guard let url = supportFileURL() else { return }
        try? ISO8601DateFormatter().string(from: date).write(to: url, atomically: true, encoding: .utf8)
    }
}

extension Notification.Name {
    static let mullionShowLicenseWindow = Notification.Name("mullionShowLicenseWindow")
    static let mullionEntitlementChanged = Notification.Name("mullionEntitlementChanged")
}
