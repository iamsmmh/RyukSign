//
//  LogsTabView.swift
//  RyukSign
//
//  Dedicated, real-time activity log tab (KSign-style). Streams every line the app
//  writes through `FileLogger` — downloads, signing, installs, tweak injection,
//  cleanup — via `ActivityLogStore`, so there is no polling. Pull to re-read the
//  on-disk file for history older than the in-memory cap.
//

import SwiftUI
import NimbleViews
import NimbleExtensions

// MARK: - View
struct LogsTabView: View {
	@ObservedObject private var _store = ActivityLogStore.shared

	enum LevelFilter: String, CaseIterable, Identifiable {
		case all
		case success
		case error

		var id: String { rawValue }

		var label: String {
			switch self {
			case .all: .localized("All")
			case .success: .localized("Success")
			case .error: .localized("Errors")
			}
		}
	}

	@State private var _filter: LevelFilter = .all

	private var _visibleEntries: [LogEntry] {
		switch _filter {
		case .all:
			_store.entries
		case .success:
			_store.entries.filter { $0.kind == .success || $0.kind == .info }
		case .error:
			_store.entries.filter { $0.kind == .error || $0.kind == .detail }
		}
	}

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Logs"), displayMode: .inline) {
			VStack(spacing: 0) {
				Picker(.localized("Level"), selection: $_filter) {
					ForEach(LevelFilter.allCases) { level in
						Text(level.label).tag(level)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
				.padding(.horizontal)
				.padding(.vertical, 8)
				.background(Color(uiColor: LogConsoleView.consoleBackgroundColor))

				LogConsoleView(
					entries: _visibleEntries,
					showCategory: true,
					onRefresh: { _store.reloadFromDisk() }
				)
				.background(Color(uiColor: LogConsoleView.consoleBackgroundColor))
				.ignoresSafeArea(edges: .bottom)
				.overlay {
					if _visibleEntries.isEmpty {
						Text(.localized("No logs yet"))
							.font(.footnote)
							.foregroundStyle(.white.opacity(0.35))
					}
				}
			}
			.toolbar {
				NBToolbarMenu(systemImage: "ellipsis.circle", style: .icon, placement: .topBarTrailing) {
					Button(.localized("Share"), systemImage: "square.and.arrow.up") {
						UIActivityViewController.show(activityItems: [FileLogger.logFileURL])
					}
					.disabled(_store.entries.isEmpty)

					Button(.localized("Refresh"), systemImage: "arrow.clockwise") {
						_store.reloadFromDisk()
					}
					Divider()
					Button(.localized("Clear"), systemImage: "trash", role: .destructive) {
						DestructiveConfirm.present(
							title: .localized("Clear Logs"),
							message: .localized("Deletes the on-device activity log, including rotated history.")
						) {
							_store.clear()
						}
					}
				}
			}
			.toolbarBackground(Color(uiColor: LogConsoleView.consoleBackgroundColor), for: .navigationBar)
			.toolbarBackground(.visible, for: .navigationBar)
			.toolbarColorScheme(.dark, for: .navigationBar)
		}
	}
}
