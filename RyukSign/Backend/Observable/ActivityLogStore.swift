//
//  ActivityLogStore.swift
//  RyukSign
//
//  In-memory, newest-first ring of activity log entries. Every line written by
//  `FileLogger` (disk, shared via Files / Web Manager) is mirrored here in real
//  time so the Logs tab streams without polling the file. Mirrors the batching
//  pattern of `SigningLog`: appends land on a serial queue, flush to the main
//  actor in one batch so SwiftUI doesn't re-render per line.
//

import Foundation

final class ActivityLogStore: ObservableObject {
	static let shared = ActivityLogStore()

	/// Newest first, like `SigningLog.lines` and the console views.
	@Published private(set) var entries: [LogEntry] = []

	private static let _maxEntries = 500
	private static let _flushInterval = 0.08

	private let _queue = DispatchQueue(label: "app.ryuksign.activitylogstore")
	private var _pending: [LogEntry] = []
	private var _flushScheduled = false

	private init() {
		// Seed with the recent on-disk history so the tab isn't empty on first open.
		entries = LogParser.parseFile(FileLogger.readAll(), limit: Self._maxEntries)
	}

	// MARK: Public

	/// Appends an info-level line (memory + disk). Call from any thread.
	func log(_ message: String, category: String = "general") {
		_append(message, level: nil, category: category)
	}

	/// Appends a success-level line (memory + disk).
	func success(_ message: String, category: String = "general") {
		_append(message, level: .success, category: category)
	}

	/// Appends an error-level line (memory + disk).
	func error(_ message: String, category: String = "general") {
		_append("ERROR: \(message)", level: .error, category: category)
	}

	/// Clears memory and disk.
	func clear() {
		_queue.async {
			FileLogger.clearDisk()
			self._pending.removeAll()
			DispatchQueue.main.async { self.entries.removeAll() }
		}
	}

	/// Re-reads the on-disk log (more history than the in-memory cap keeps).
	func reloadFromDisk() {
		_queue.async {
			let parsed = LogParser.parseFile(FileLogger.readAll(), limit: Self._maxEntries)
			DispatchQueue.main.async { self.entries = parsed }
		}
	}

	// MARK: Internal

	private func _append(_ rawMessage: String, level: LogKind?, category: String) {
		let classified = LogParser.classify(rawMessage, level: level)
		let text = classified.text.trimmingCharacters(in: .whitespaces)
		guard !text.isEmpty else { return }

		// The disk line keeps the markers `LogParser.parseFile` uses to re-classify
		// (ERROR: prefix, ">>>" detail marker) so history reads the same as memory.
		let fileLine: String
		switch classified.kind {
		case .error: fileLine = "ERROR: \(text)"
		case .detail: fileLine = ">>> \(text)"
		default: fileLine = text
		}

		let entry = LogEntry(date: Date(), category: category, message: text, kind: classified.kind)

		_queue.async {
			FileLogger.writeDisk(fileLine, category: category)

			self._pending.append(entry)
			guard !self._flushScheduled else { return }
			self._flushScheduled = true
			self._queue.asyncAfter(deadline: .now() + Self._flushInterval) { self._flush() }
		}
	}

	private func _flush() {
		_flushScheduled = false
		guard !_pending.isEmpty else { return }

		let batch = Array(_pending.reversed())
		_pending.removeAll(keepingCapacity: true)

		DispatchQueue.main.async {
			self.entries.insert(contentsOf: batch, at: 0)
			if self.entries.count > Self._maxEntries {
				self.entries.removeLast(self.entries.count - Self._maxEntries)
			}
		}
	}
}
