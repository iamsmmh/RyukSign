//
//  FileManagerModel.swift
//  RyukSign
//
//  Backing model for the in-app Files browser (KSign-style). Browses the app's
//  own Documents container — Archives, Signed, Unsigned, Certificates, Tweaks,
//  Logs — and supports creating, renaming, and deleting entries. Every mutation
//  is confined to Documents; nothing can escape the container.
//

import Foundation
import UIKit

@MainActor
final class FileManagerModel: ObservableObject {
	struct Item: Identifiable, Hashable {
		let url: URL
		let isDirectory: Bool
		let size: Int64
		let modified: Date?

		var id: String { url.path }
		var name: String { url.lastPathComponent }
	}

	static var root: URL { URL.documentsDirectory }

	@Published private(set) var currentURL: URL
	@Published private(set) var items: [Item] = []
	@Published private(set) var isLoading = false

	init(url: URL = URL.documentsDirectory) {
		self.currentURL = url
	}

	var isRoot: Bool { currentURL.standardizedFileURL.path == Self.root.standardizedFileURL.path }
	var canGoUp: Bool { !isRoot }

	// MARK: Browsing

	func load() {
		isLoading = true
		defer { isLoading = false }

		let fm = FileManager.default
		let keys: Set<URLResourceKey> = [
			.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey, .fileModifiedDateTimeKey
		]

		let urls = (try? fm.contentsOfDirectory(
			at: currentURL,
			includingPropertiesForKeys: Array(keys),
			options: [.skipsHiddenFiles]
		)) ?? []

		var built: [Item] = []
		built.reserveCapacity(urls.count)

		for url in urls {
			let values = try? url.resourceValues(forKeys: keys)
			let isDirectory = values?.isDirectory ?? false
			let size: Int64 = isDirectory ? 0 : Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
			built.append(Item(url: url, isDirectory: isDirectory, size: size, modified: values?.fileModifiedDateTime))
		}

		built.sort { a, b in
			if a.isDirectory != b.isDirectory { return a.isDirectory }
			return a.name.localizedStandardCompare(b.name) == .orderedAscending
		}

		items = built
	}

	func goUp() {
		guard canGoUp else { return }
		currentURL = currentURL.deletingLastPathComponent()
		load()
	}

	func enter(_ item: Item) {
		guard item.isDirectory else { return }
		currentURL = item.url
		load()
	}

	// MARK: Mutations (confined to Documents)

	private func isInsideDocuments(_ url: URL) -> Bool {
		let candidate = url.standardizedFileURL.path
		let root = Self.root.standardizedFileURL.path
		return candidate == root || candidate.hasPrefix(root + "/")
	}

	@discardableResult
	func createFile(named rawName: String) -> Bool {
		_create(rawName, isDirectory: false)
	}

	@discardableResult
	func createFolder(named rawName: String) -> Bool {
		_create(rawName, isDirectory: true)
	}

	private func _create(_ rawName: String, isDirectory: Bool) -> Bool {
		let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/") else { return false }

		let url = currentURL.appendingPathComponent(name)
		guard isInsideDocuments(url), !FileManager.default.fileExists(atPath: url.path) else { return false }

		do {
			if isDirectory {
				try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
			} else {
				FileManager.default.createFile(atPath: url.path, contents: nil)
			}
			FileLogger.log("\(isDirectory ? "Created folder" : "Created file"): \(name)", category: "files")
			load()
			return true
		} catch {
			FileLogger.error("Failed to create \(isDirectory ? "folder" : "file") "\(name)": \(error.localizedDescription)", category: "files")
			return false
		}
	}

	@discardableResult
	func delete(_ item: Item) -> Bool {
		guard isInsideDocuments(item.url) else { return false }

		do {
			try FileManager.default.removeItem(at: item.url)
			FileLogger.log("Deleted: \(item.name)", category: "files")
			load()
			return true
		} catch {
			FileLogger.error("Delete failed: \(item.name) — \(error.localizedDescription)", category: "files")
			return false
		}
	}

	@discardableResult
	func rename(_ item: Item, to rawNewName: String) -> Bool {
		let newName = rawNewName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !newName.isEmpty, !newName.hasPrefix("."), !newName.contains("/"), newName != item.name else { return false }

		let destination = item.url.deletingLastPathComponent().appendingPathComponent(newName)
		guard isInsideDocuments(destination), !FileManager.default.fileExists(atPath: destination.path) else { return false }

		do {
			try FileManager.default.moveItem(at: item.url, to: destination)
			FileLogger.log("Renamed: \(item.name) → \(newName)", category: "files")
			load()
			return true
		} catch {
			FileLogger.error("Rename failed: \(item.name) — \(error.localizedDescription)", category: "files")
			return false
		}
	}

	// MARK: Text detection

	private static let _textExtensions: Set<String> = [
		"txt", "log", "json", "plist", "xml", "entitlements", "mobileconfig",
		"md", "markdown", "swift", "js", "ts", "py", "sh", "yml", "yaml",
		"ini", "conf", "cfg", "pem", "crt", "cer", "info", "strings",
		"html", "css", "sql", "csv", "tsv"
	]

	/// True for files the in-app editor can open: a known text extension and,
	/// for `.plist`, not a binary (bplist) file.
	static func isTextFile(_ url: URL) -> Bool {
		let ext = url.pathExtension.lowercased()
		guard _textExtensions.contains(ext) else { return false }

		if ext == "plist", let head = try? Data(contentsOf: url, options: .readOnlyUpToLength(10)), head.count >= 10 {
			if head.subdata(in: 4..<10) == Data("bplist".utf8) { return false }
		}

		return true
	}
}
