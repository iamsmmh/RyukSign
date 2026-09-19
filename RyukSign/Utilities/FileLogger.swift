//
//  FileLogger.swift
//  RyukSign
//
//  Lightweight append-only logger that writes to the app's Documents folder so a user can
//  pull it over USB (Documents is exposed via UIFileSharingEnabled) or via Web Manager.
//  Mirrors to OSLog. Used to debug signing/tweak issues that otherwise vanish on device.
//
//  Every call is mirrored into `ActivityLogStore` (in-memory ring, drives the live Logs
//  tab). The disk format is unchanged: `ISO8601 [category] message`, rotated at ~2 MB.
//

import Foundation
import OSLog

enum FileLogger {
	private static let _queue = DispatchQueue(label: "app.ryuksign.filelogger")
	private static let _fm = FileManager.default
	private static let _maxBytes: UInt64 = 2 * 1024 * 1024 // rotate at ~2 MB

	/// `Documents/Logs/ryuksign.log`
	static var logFileURL: URL {
		_fm.logs.appendingPathComponent("ryuksign.log")
	}

	private static var _rotatedFileURL: URL {
		logFileURL.deletingPathExtension().appendingPathExtension("1.log")
	}

	// MARK: Public API — feeds memory + disk

	static func log(_ message: String, category: String = "general") {
		ActivityLogStore.shared.log(message, category: category)
	}

	static func success(_ message: String, category: String = "general") {
		ActivityLogStore.shared.success(message, category: category)
	}

	static func error(_ message: String, category: String = "general") {
		ActivityLogStore.shared.error(message, category: category)
	}

	/// Disk-only write. Called by `ActivityLogStore` with a line that already carries
	/// the classification markers (`ERROR:`, `>>>`), so file history re-parses identically.
	static func writeDisk(_ line: String, category: String) {
		Logger.misc.info("[\(category, privacy: .public)] \(line, privacy: .public)")
		let formatted = "\(_timestamp()) [\(category)] \(line)\n"
		_queue.async {
			let url = logFileURL
			do {
				try _fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
				_rotateIfNeeded(url)
				if let handle = try? FileHandle(forWritingTo: url) {
					defer { try? handle.close() }
					try handle.seekToEnd()
					handle.write(Data(formatted.utf8))
				} else {
					try Data(formatted.utf8).write(to: url, options: .atomic)
				}
			} catch {
				Logger.misc.error("FileLogger write failed: \(error.localizedDescription)")
			}
		}
	}

	/// Current log contents (for an in-app share/export).
	static func read() -> String {
		(try? String(contentsOf: logFileURL, encoding: .utf8)) ?? ""
	}

	/// Full history including the rotated file, oldest first.
	static func readAll() -> String {
		let rotated = (try? String(contentsOf: _rotatedFileURL, encoding: .utf8)) ?? ""
		return rotated + read()
	}

	static func clear() {
		ActivityLogStore.shared.clear()
	}

	/// Disk-only clear. Called by `ActivityLogStore.clear()`.
	static func clearDisk() {
		_queue.async {
			try? _fm.removeItem(at: logFileURL)
			try? _fm.removeItem(at: _rotatedFileURL)
		}
	}

	// MARK: Internal

	private static func _rotateIfNeeded(_ url: URL) {
		guard
			let attrs = try? _fm.attributesOfItem(atPath: url.path),
			let bytes = attrs[.size] as? UInt64,
			bytes > _maxBytes
		else { return }
		let rotated = url.deletingPathExtension().appendingPathExtension("1.log")
		try? _fm.removeItem(at: rotated)
		try? _fm.moveItem(at: url, to: rotated)
	}

	private static func _timestamp() -> String {
		let f = ISO8601DateFormatter()
		f.formatOptions = [.withInternetDateTime]
		return f.string(from: Date())
	}
}
