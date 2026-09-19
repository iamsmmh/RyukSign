//
//  AntiRevokeManager.swift
//  RyukSign
//
//  DNS anti-revoke (KSign / FlareStore-style): generates a `.mobileconfig`
//  that overrides the device DNS with public resolvers (1.1.1.1 / 8.8.8.8)
//  that don't serve Apple's OCSP/CRL revocation the same way the carrier
//  default does, slowing the ~7-day revocation of signed apps.
//
//  Modern iOS (16+) does not allow apps to install configuration profiles
//  programmatically, so the profile is handed to the share sheet, whose
//  built-in "Install Profile" action completes the install in Settings.
//  The profile is also kept in `Documents/AntiRevoke/` so the user can
//  re-install it at any time, and removal is a guided manual step — iOS
//  offers no public API to remove user-installed profiles.
//
//  The installed flag is best-effort: it is set when the user takes the
//  install action, because iOS never calls back with the outcome.
//

import Foundation
import UIKit
import NimbleExtensions

enum AntiRevokeManager {
	/// Identifier of the payload; matching identifiers on re-install replace in place.
	static let identifier = "com.ryuksign.antirevoke.dns"

	static let dnsServers = ["1.1.1.1", "8.8.8.8"]

	private static let _installedKey = "Feather.antiRevokeInstalled"

	/// Best-effort status (see the file header for why it can't be verified).
	static var isInstalled: Bool {
		UserDefaults.standard.bool(forKey: _installedKey)
	}

	/// Where the generated profile lives, for re-install or sharing.
	static var profileURL: URL {
		URL.documentsDirectory
			.appendingPathComponent("AntiRevoke", isDirectory: true)
			.appendingPathComponent("RyukSign-AntiRevoke.mobileconfig")
	}

	// MARK: Profile generation

	/// Builds the profile payload. The DNS payload replaces the device's DNS
	/// servers with the ones in `dnsServers` — it does not touch Wi-Fi or
	/// cellular connectivity otherwise.
	static func profileData() -> Data {
		let dnsSettings: [String: Any] = [
			"PayloadContent": [["ServerAddresses": dnsServers]],
			"PayloadIdentifier": "\(identifier).settings",
			"PayloadType": "com.apple.dns.settings",
			"PayloadUUID": UUID().uuidString,
			"PayloadVersion": 1
		]

		let payload: [String: Any] = [
			"PayloadContent": [dnsSettings],
			"PayloadDisplayName": "RyukSign Anti-Revoke DNS",
			"PayloadIdentifier": identifier,
			"PayloadType": "Configuration",
			"PayloadUUID": UUID().uuidString,
			"PayloadVersion": 1
		]

		return (try? PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0))
			?? Data()
	}

	/// (Re)writes the profile into `Documents/AntiRevoke/` and returns its URL.
	static func writeProfile() throws -> URL {
		let url = profileURL
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try profileData().write(to: url, options: .atomic)
		return url
	}

	// MARK: Install / remove flow

	/// Regenerates the profile and presents the share sheet. iOS shows an
	/// "Install Profile" action for `.mobileconfig` items, which walks the
	/// user through the Settings install.
	static func presentInstall() {
		do {
			let url = try writeProfile()
			markInstalled()
			UIActivityViewController.show(activityItems: [url])
		} catch {
			FileLogger.error("Anti-revoke profile generation failed: \(error.localizedDescription)", category: "antirevoke")
			Toast.error(.localized("Couldn't generate the DNS profile"), duration: .long)
		}
	}

	/// Sets the best-effort installed flag after the user takes the install action.
	static func markInstalled() {
		UserDefaults.standard.set(true, forKey: _installedKey)
		FileLogger.log("Anti-revoke DNS profile install started", category: "antirevoke")
	}

	/// Clears the flag after the user confirms they removed the profile in Settings.
	static func markRemoved() {
		UserDefaults.standard.set(false, forKey: _installedKey)
		FileLogger.log("Anti-revoke DNS profile marked removed", category: "antirevoke")
	}
}
