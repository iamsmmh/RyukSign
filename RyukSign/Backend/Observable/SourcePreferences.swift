//
//  SourcePreferences.swift
//  RyukSign
//
//  Pin / hide / last-refresh / last-error for repositories, plus "hide duplicate apps"
//  when browsing All Repositories.
//

import Foundation

enum SourcePreferences {
	private static let pinnedKey = "RyukSign.sources.pinned"
	private static let lastFetchKey = "RyukSign.sources.lastFetch"
	private static let lastErrorKey = "RyukSign.sources.lastError"
	private static let hideDuplicatesKey = "RyukSign.sources.hideDuplicates"

	static var hideDuplicates: Bool {
		get { UserDefaults.standard.bool(forKey: hideDuplicatesKey) }
		set { UserDefaults.standard.set(newValue, forKey: hideDuplicatesKey) }
	}

	static func isPinned(_ id: String) -> Bool {
		pinned.contains(id)
	}

	static func setPinned(_ id: String, pinned isPinned: Bool) {
		var set = pinned
		if isPinned { set.insert(id) } else { set.remove(id) }
		UserDefaults.standard.set(Array(set), forKey: pinnedKey)
	}

	static func lastFetch(for id: String) -> Date? {
		guard let map = UserDefaults.standard.dictionary(forKey: lastFetchKey) as? [String: Double] else { return nil }
		guard let value = map[id] else { return nil }
		return Date(timeIntervalSince1970: value)
	}

	static func lastError(for id: String) -> String? {
		(UserDefaults.standard.dictionary(forKey: lastErrorKey) as? [String: String])?[id]
	}

	static func recordFetch(id: String, error: String?) {
		var fetches = UserDefaults.standard.dictionary(forKey: lastFetchKey) as? [String: Double] ?? [:]
		fetches[id] = Date().timeIntervalSince1970
		UserDefaults.standard.set(fetches, forKey: lastFetchKey)

		var errors = UserDefaults.standard.dictionary(forKey: lastErrorKey) as? [String: String] ?? [:]
		if let error, !error.isEmpty {
			errors[id] = error
		} else {
			errors.removeValue(forKey: id)
		}
		UserDefaults.standard.set(errors, forKey: lastErrorKey)
	}

	private static var pinned: Set<String> {
		Set(UserDefaults.standard.stringArray(forKey: pinnedKey) ?? [])
	}
}
