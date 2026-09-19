//
//  CleanupHistory.swift
//  VexSign
//
//  A rolling record of what Auto Cleanup actually removed, so an invisible tool stays
//  trustworthy: one line per run ("2 apps, 1.4 GB") plus an undo-friendly list of names.
//  The manager keeps the last N entries, capped so history can never grow large.
//

import Foundation
import SwiftUI
import NimbleExtensions

// MARK: - Entry
struct CleanupHistoryEntry: Codable, Identifiable, Equatable {
	let id: String
	let date: Date
	let removedApps: [String]
	let categories: [String]
	let freedBytes: Int64

	var totalFreed: Int64 { freedBytes }

	var appSummary: String {
		guard !removedApps.isEmpty else {
			return String.localized("%lld categories cleaned", arguments: max(categories.count, 1))
		}
		return removedApps.count == 1
			? removedApps[0]
			: String.localized("%lld apps", arguments: removedApps.count)
	}
}

// MARK: - Store
final class CleanupHistoryStore: ObservableObject {
	static let shared = CleanupHistoryStore()

	private static let defaultsKey = "VexSign.cleanup.history"
	private static let maxEntries = 60

	@Published private(set) var entries: [CleanupHistoryEntry]

	private init() {
		guard
			let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
			let decoded = try? JSONDecoder().decode([CleanupHistoryEntry].self, from: data)
		else {
			entries = []
			return
		}
		entries = decoded
	}

	private func persist() {
		guard let data = try? JSONEncoder().encode(entries) else { return }
		UserDefaults.standard.set(data, forKey: Self.defaultsKey)
	}

	func record(apps: [String], categories: [StorageCategory], freedBytes: Int64) {
		guard !apps.isEmpty || !categories.isEmpty || freedBytes > 0 else { return }

		let entry = CleanupHistoryEntry(
			id: UUID().uuidString,
			date: Date(),
			removedApps: apps,
			categories: categories.map(\.rawValue),
			freedBytes: freedBytes
		)

		entries.insert(entry, at: 0)
		if entries.count > Self.maxEntries {
			entries.removeLast(entries.count - Self.maxEntries)
		}
		persist()
	}

	func clear() {
		entries = []
		persist()
	}

	/// Total space freed across the retained history, for a printed trend.
	var totalFreedInHistory: Int64 {
		entries.reduce(0) { $0 + $1.freedBytes }
	}
}

// MARK: - Storage rules

/// Optional "keep the last signed copy of each app" and "warn over N GB" rules,
/// exercised by the automatic sweep.
enum StorageRules {
	static let keepOnlyLatestKey = "VexSign.storage.keepOnlyLatestSigned"
	static let warnGigabytesKey = "VexSign.storage.warnGigabytes"

	static var keepOnlyLatestSigned: Bool {
		get { UserDefaults.standard.bool(forKey: keepOnlyLatestKey) }
		set { UserDefaults.standard.set(newValue, forKey: keepOnlyLatestKey) }
	}

	/// 0 = off. Otherwise toast when VexSign's documents folder exceeds this many GB.
	static var warnGigabytes: Int {
		get { UserDefaults.standard.object(forKey: warnGigabytesKey) as? Int ?? 0 }
		set { UserDefaults.standard.set(newValue, forKey: warnGigabytesKey) }
	}

	static func warnIfOverLimit() {
		guard warnGigabytes > 0 else { return }
		let used = FileManager.default.allocatedSize(at: URL.documentsDirectory)
		let limit = Int64(warnGigabytes) * 1_000_000_000
		guard used > limit else { return }
		Toast.error(
			.localized("VexSign is using %@ — over the %lld GB warning.", arguments: used.formattedFileSize, warnGigabytes),
			duration: .long
		)
	}

	/// Prunes duplicate signed copies of the same bundle id, keeping the highest version.
	/// Returns the app names that were removed and how much they freed.
	@discardableResult
	static func pruneDuplicateSignedApps() -> (removed: [String], freed: Int64) {
		guard keepOnlyLatestSigned else { return ([], 0) }

		let signed = Storage.shared.getAllApps().filter(\.isSigned)
		var byIdentifier: [String: [AppInfoPresentable]] = [:]

		for app in signed {
			guard let id = app.identifier ?? app.name else { continue }
			byIdentifier[id, default: []].append(app)
		}

		var targets: [AppInfoPresentable] = []
		for (_, group) in byIdentifier where group.count > 1 {
			// Keep the highest version; delete the rest.
			let ordered = group.sorted { version($0) > version($1) }
			targets.append(contentsOf: ordered.dropFirst())
		}

		guard !targets.isEmpty else { return ([], 0) }

		let freed = targets.reduce(Int64(0)) { total, app in
			guard let dir = Storage.shared.getUuidDirectory(for: app) else { return total }
			return total + FileManager.default.allocatedSize(at: dir)
		}
		let names = targets.compactMap { $0.name }
		Storage.shared.deleteApps(targets)
		return (names, freed)
	}

	private static func version(_ app: AppInfoPresentable) -> String {
		guard let v = app.version else { return "" }

		let parts = v.split(separator: ".").compactMap { Int($0) }
		return parts.map { String(format: "%06d", $0) }.joined()
	}
}
