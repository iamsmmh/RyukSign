//
//  SigningProfileStore.swift
//  VexSign
//
//  "Sign it again exactly like that": a persisted snapshot of the full signing
//  options plus the chosen certificate, keyed by bundle identifier. Update All
//  and "Re-sign with last settings" both read from here, so an app is updated
//  with the identity it was first signed with instead of re-picking everything.
//

import Foundation

// MARK: - Model
struct SigningProfile: Codable, Equatable {
	/// Bundle identifier the profile was captured for (the app's own id, not the PPQ-mangled one).
	let bundleID: String
	/// Full options snapshot — tweaks, entitlements, Info.plist overrides, display name, keychain isolation.
	let options: Options
	/// The `CertificatePair.uuid` used at capture. `nil` means "default / whatever is selected now".
	let certificateUUID: String?
	/// When it was last used, for display in the picker.
	let savedAt: Date
}

// MARK: - Store
/// Backed by UserDefaults (JSON) — small snapshots, keyed by bundle id. `Codable` via `Options`.
final class SigningProfileStore {
	static let shared = SigningProfileStore()

	private static let defaultsKey = "VexSign.signingProfiles"

	private init() {}

	// MARK: Read / write

	private var all: [String: SigningProfile] {
		get {
			guard
				let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
				let decoded = try? JSONDecoder().decode([String: SigningProfile].self, from: data)
			else {
				return [:]
			}
			return decoded
		}
		set {
			if newValue.isEmpty {
				UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
			} else if let data = try? JSONEncoder().encode(newValue) {
				UserDefaults.standard.set(data, forKey: Self.defaultsKey)
			}
		}
	}

	func profile(forBundleID bundleID: String?) -> SigningProfile? {
		guard let bundleID, !bundleID.isEmpty else { return nil }
		return all[bundleID]
	}

	func save(_ profile: SigningProfile) {
		guard !profile.bundleID.isEmpty else { return }
		var store = all
		store[profile.bundleID] = profile
		all = store
	}

	func remove(bundleID: String?) {
		guard let bundleID, !bundleID.isEmpty else { return }
		var store = all
		store.removeValue(forKey: bundleID)
		all = store
	}

	func clear() {
		all = [:]
	}

	// MARK: Convenience

	/// Records the options + certificate used to sign `app`, so the next sign (or Update All)
	/// can reproduce it without touching the signing screen.
	func capture(options: Options, certificate: CertificatePair?, for app: AppInfoPresentable) {
		guard let bundleID = app.identifier, !bundleID.isEmpty else { return }

		// Per-app identity fields must not be persisted in the shared defaults or every later
		// "resolved(for:)" would adopt this app's mangled identifier.
		var snapshot = options
		snapshot.appName = nil
		snapshot.appVersion = nil
		snapshot.appIdentifier = nil
		snapshot.appEntitlementsFile = nil

		save(SigningProfile(
			bundleID: bundleID,
			options: snapshot,
			certificateUUID: certificate?.uuid,
			savedAt: Date()
		))
	}

	func capture(options: Options, certificateUUID: String?, for app: AppInfoPresentable) {
		guard let bundleID = app.identifier, !bundleID.isEmpty else { return }

		var snapshot = options
		snapshot.appName = nil
		snapshot.appVersion = nil
		snapshot.appIdentifier = nil
		snapshot.appEntitlementsFile = nil

		save(SigningProfile(
			bundleID: bundleID,
			options: snapshot,
			certificateUUID: certificateUUID,
			savedAt: Date()
		))
	}

	/// Resolves the certificate a stored profile points at, falling back to the app-wide selection.
	func certificate(for profile: SigningProfile?) -> CertificatePair? {
		guard let uuid = profile?.certificateUUID else {
			return Storage.shared.getCertificate(for: UserDefaults.standard.integer(forKey: "vexsign.selectedCert"))
		}
		return Storage.shared.getAllCertificates().first { $0.uuid == uuid }
			?? Storage.shared.getCertificate(for: UserDefaults.standard.integer(forKey: "vexsign.selectedCert"))
	}
}
