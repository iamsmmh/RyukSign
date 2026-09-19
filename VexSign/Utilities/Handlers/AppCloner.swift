//
//  AppCloner.swift
//  VexSign
//
//  Clones/duplicates an existing app bundle with a modified bundle ID and display name,
//  storing the duplicate as a new independent library entry.
//

import Foundation
import UIKit

@MainActor
final class AppCloner {
	static let shared = AppCloner()

	private let _fm = FileManager.default

	enum CloneError: LocalizedError {
		case appNotFound
		case copyFailed
		case plistFailed

		var errorDescription: String? {
			switch self {
			case .appNotFound: String.localized("App files not found.")
			case .copyFailed: String.localized("Failed to duplicate app files.")
			case .plistFailed: String.localized("Failed to update Info.plist.")
			}
		}
	}

	func clone(app: AppInfoPresentable, customName: String? = nil, customBundleId: String? = nil) async throws -> AppInfoPresentable {
		guard let srcDir = Storage.shared.getUuidDirectory(for: app), _fm.fileExists(atPath: srcDir.path) else {
			throw CloneError.appNotFound
		}

		let newUUID = UUID().uuidString
		let destDir = app.isSigned ? _fm.signed(newUUID) : _fm.unsigned(newUUID)

		do {
			try _fm.copyItem(at: srcDir, to: destDir)
		} catch {
			try? _fm.removeItem(at: destDir)
			throw CloneError.copyFailed
		}

		guard let appBundle = _fm.getPath(in: destDir, for: "app") else {
			try? _fm.removeItem(at: destDir)
			throw CloneError.appNotFound
		}

		let newName = customName ?? "\(app.name ?? .localized("App")) Copy"
		let newBundleId = customBundleId ?? "\(app.identifier ?? "app").copy"

		// Update Info.plist
		let infoPlistURL = appBundle.appendingPathComponent("Info.plist")
		if var plist = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] {
			plist["CFBundleName"] = newName
			plist["CFBundleDisplayName"] = newName
			plist["CFBundleIdentifier"] = newBundleId
			if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) {
				try? data.write(to: infoPlistURL)
			}
		}

		// Register in database
		return try await withCheckedThrowingContinuation { continuation in
			if app.isSigned {
				Storage.shared.addSigned(
					uuid: newUUID,
					appName: newName,
					appIdentifier: newBundleId,
					originalAppIdentifier: app.originalIdentifier ?? app.identifier,
					appVersion: app.version,
					appIcon: app.icon,
					appDescription: app.appDescription
				) { signed in
					continuation.resume(returning: signed)
				}
			} else {
				Storage.shared.addImported(
					uuid: newUUID,
					appName: newName,
					appIdentifier: newBundleId,
					appVersion: app.version,
					appIcon: app.icon,
					appDescription: app.appDescription
				) { error in
					if let error {
						continuation.resume(throwing: error)
					} else if let imported = Storage.shared.app(withUuid: newUUID) {
						continuation.resume(returning: imported)
					} else {
						continuation.resume(throwing: CloneError.copyFailed)
					}
				}
			}
		}
	}
}
