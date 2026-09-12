import Foundation
import AuthenticationServices
import CloudKit
import Observation

/// Whether the SwiftData store is syncing to iCloud or running locally.
@Observable
@MainActor
final class CloudSyncState {
    static let shared = CloudSyncState()
    enum Mode: Equatable {
        case cloud
        case local(String)
    }
    var mode: Mode = .local("not started")
    var isCloud: Bool { mode == .cloud }
}

/// Sign in with Apple identity + iCloud availability. Signing in gives the
/// user a named account inside Phantom (and prefills the dispute-letter
/// signature); the data itself rides CloudKit under the device's iCloud
/// account, so "signed in" and "syncing" are shown separately.
@Observable
@MainActor
final class AccountService {
    static let shared = AccountService()

    private static let userIDKey = "apple.userID"
    private static let nameKey = "phantom.account.name"
    private static let emailKey = "phantom.account.email"

    private(set) var appleUserID: String?
    private(set) var displayName: String
    private(set) var email: String
    private(set) var iCloudStatus: CKAccountStatus = .couldNotDetermine
    private(set) var lastError: String?

    init() {
        appleUserID = KeychainStore.get(Self.userIDKey)
        displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        email = UserDefaults.standard.string(forKey: Self.emailKey) ?? ""
    }

    var isSignedIn: Bool { appleUserID != nil }

    var iCloudAvailable: Bool { iCloudStatus == .available }

    /// True when both halves are in place: the store opened with CloudKit and
    /// the device has an iCloud account.
    var syncActive: Bool { iCloudAvailable && CloudSyncState.shared.isCloud }

    var syncStatusText: String {
        switch (CloudSyncState.shared.mode, iCloudStatus) {
        case (.cloud, .available): return "iCloud sync on"
        case (.cloud, .noAccount): return "Sign in to iCloud in iOS Settings to sync"
        case (.cloud, .restricted): return "iCloud restricted on this device"
        case (.cloud, _): return "Checking iCloud…"
        case (.local, _): return CloudEntitlements.hasCloudKit ? "Stored on this iPhone only" : "Stored on this iPhone only (this build has no iCloud entitlement)"
        }
    }

    /// Configure the Apple ID request (name + email are only delivered on the
    /// very first authorization for this Apple ID + app).
    nonisolated func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Handle the button's completion. Returns true on success.
    @discardableResult
    func handle(_ result: Result<ASAuthorization, Error>) -> Bool {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return false }
            lastError = error.localizedDescription
            return false
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                lastError = "Unsupported credential"
                return false
            }
            return apply(userID: credential.user, name: credential.fullName, email: credential.email)
        }
    }

    /// Pure core of `handle` (testable): stores the identity, keeps a
    /// previously captured name/email when Apple omits them on re-auth.
    @discardableResult
    func apply(userID: String, name: PersonNameComponents?, email: String?) -> Bool {
        guard !userID.isEmpty else { return false }
        KeychainStore.set(userID, for: Self.userIDKey)
        appleUserID = userID
        if let formatted = Self.format(name), !formatted.isEmpty {
            displayName = formatted
            UserDefaults.standard.set(formatted, forKey: Self.nameKey)
        }
        if let email, !email.isEmpty {
            self.email = email
            UserDefaults.standard.set(email, forKey: Self.emailKey)
        }
        lastError = nil
        return true
    }

    nonisolated static func format(_ name: PersonNameComponents?) -> String? {
        guard let name else { return nil }
        let f = PersonNameComponentsFormatter()
        f.style = .default
        let s = f.string(from: name).trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }

    /// Re-check the Apple ID credential (revoked in iOS Settings?) and the
    /// iCloud account. Called on launch and when the app becomes active.
    func refresh() async {
        if let id = appleUserID {
            let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: id)
            if state == .revoked || state == .notFound {
                signOut()
            }
        }
        guard CloudEntitlements.hasCloudKit else {
            iCloudStatus = .couldNotDetermine
            return
        }
        if let status = try? await CKContainer(identifier: AppConfig.cloudKitContainerID).accountStatus() {
            iCloudStatus = status
        }
    }

    /// Forget the Apple ID inside Phantom. Data is NOT touched — it stays on
    /// this iPhone and in the user's iCloud.
    func signOut() {
        KeychainStore.remove(Self.userIDKey)
        appleUserID = nil
        displayName = ""
        email = ""
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
    }
}
