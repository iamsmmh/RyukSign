//
//  CleanupView.swift
//  RyukSign
//
//  Settings → Auto Cleanup. Every cleanup the app can do on its own, in one place, with a master
//  switch and a manual "Clean Now" for good measure.
//

import SwiftUI
import NimbleViews
import NimbleExtensions

// MARK: - View
struct CleanupView: View {
	@ObservedObject private var _manager = CleanupManager.shared

	@AppStorage(CleanupManager.Key.enabled) private var _isEnabled: Bool = true
	@AppStorage(CleanupManager.Key.oneTapInstall) private var _oneTapInstall: Bool = false

	@AppStorage(CleanupManager.Key.deleteAfterInstall) private var _deleteAfterInstall: Bool = false
	@AppStorage(CleanupManager.Key.deleteDownloadedIPA) private var _deleteDownloadedIPA: Bool = false

	@AppStorage(CleanupManager.Key.deleteSourceAfterSign) private var _deleteSourceAfterSign: Bool = false
	@AppStorage(CleanupManager.Key.deleteSignedAfterSign) private var _deleteSignedAfterSign: Bool = false

	@AppStorage(CleanupManager.Key.clearCache) private var _clearCache: Bool = false
	@AppStorage(CleanupManager.Key.clearTemporary) private var _clearTemporary: Bool = false
	@AppStorage(CleanupManager.Key.removeLeftovers) private var _removeLeftovers: Bool = false
	@AppStorage(CleanupManager.Key.clearArchives) private var _clearArchives: Bool = false

	@State private var _reclaimable: Int64 = 0
	@State private var _isCleaning = false

	// MARK: Body
	var body: some View {
		NBList(.localized("Auto Cleanup")) {
			_masterSection
			_pipelineSection

			if _isEnabled {
				_afterInstalling
				_afterSigning
				_storage
			}

			_nowSection
			_lastRunSection
		}
		.task { await _refreshReclaimable() }
		.onChange(of: _isEnabled) { _ in Task { await _refreshReclaimable() } }
		.onChange(of: _clearCache) { _ in Task { await _refreshReclaimable() } }
		.onChange(of: _clearTemporary) { _ in Task { await _refreshReclaimable() } }
		.onChange(of: _removeLeftovers) { _ in Task { await _refreshReclaimable() } }
		.onChange(of: _clearArchives) { _ in Task { await _refreshReclaimable() } }
	}
}

// MARK: - Sections
extension CleanupView {
	@ViewBuilder
	private var _masterSection: some View {
		Section {
			Toggle(.localized("Auto Cleanup"), isOn: $_isEnabled)
		} footer: {
			Text(.localized("Runs the options below by itself every time signing or installing finishes, so nothing has to be deleted or cleaned up by hand. Turn this off to keep every app and cache."))
		}
	}

	@ViewBuilder
	private var _pipelineSection: some View {
		NBSection(.localized("Automation")) {
			Toggle(isOn: Binding(
				get: { _oneTapInstall || _manager.isOneTapInstall },
				set: { _manager.setOneTapInstall($0) }
			)) {
				Label(.localized("One-Tap Install"), systemImage: "wand.and.stars")
			}
		} footer: {
			VStack(alignment: .leading, spacing: 6) {
				Text(.localized("Import or download an app and RyukSign signs it, installs it, deletes the app from your library and clears the caches — no taps in between."))

				if !AutoSignManager.canSign {
					Text(.localized("Import a certificate first, otherwise signing cannot run on its own."))
						.foregroundStyle(.orange)
				}
			}
		}
	}

	@ViewBuilder
	private var _afterInstalling: some View {
		NBSection(.localized("After Installing")) {
			Toggle(.localized("Delete Installed App"), isOn: $_deleteAfterInstall)
			Toggle(.localized("Delete Downloaded IPA"), isOn: $_deleteDownloadedIPA)
		} footer: {
			Text(.localized("The app stays installed on your device — only the copy in RyukSign's library is removed. The IPA is the file RyukSign downloaded or imported before signing."))
		}
	}

	@ViewBuilder
	private var _afterSigning: some View {
		NBSection(.localized("After Signing")) {
			Toggle(.localized("Delete Unsigned App"), isOn: $_deleteSourceAfterSign)
			Toggle(.localized("Delete Signed App"), isOn: $_deleteSignedAfterSign)
		} footer: {
			VStack(alignment: .leading, spacing: 6) {
				Text(.localized("The unsigned app is the file you imported; it is only needed to produce the signed copy."))

				Text(.localized("Delete Signed App only applies when the app is not being installed or exported right after signing, and removes the signed copy from your library."))
			}
		}
	}

	@ViewBuilder
	private var _storage: some View {
		NBSection(.localized("Storage")) {
			Toggle(.localized("Clear Caches"), isOn: $_clearCache)
			Toggle(.localized("Clear Temporary Files"), isOn: $_clearTemporary)
			Toggle(.localized("Remove Leftovers"), isOn: $_removeLeftovers)
			Toggle(.localized("Delete Exported IPAs"), isOn: $_clearArchives)
		} footer: {
			Text(.localized("Caches are icons and web data, rebuilt as you browse. Temporary files and leftovers are work files from imports and signings. Exported IPAs are the ones saved every time you export or share an app."))
		}
	}

	@ViewBuilder
	private var _nowSection: some View {
		NBSection(.localized("Clean Now")) {
			Button {
				_clean()
			} label: {
				HStack {
					Label(.localized("Clean Storage Now"), systemImage: "sparkles")
					Spacer()
					if _isCleaning {
						ProgressView()
					} else if _reclaimable > 0 {
						Text(verbatim: _reclaimable.formattedFileSize)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
			}
			.disabled(_isCleaning)

			Button(role: .destructive) {
				DestructiveConfirm.present(
					title: .localized("Clear IPA Explorer Workspaces?"),
					message: .localized("Every IPA you unpacked in the IPA Explorer will be deleted. Apps in your library are not touched.")
				) {
					IPAWorkspace.discardAll()
					Toast.success(.localized("Workspaces cleared"), systemImage: "trash")
				}
			} label: {
				Label(.localized("Clear IPA Explorer Workspaces"), systemImage: "doc.zipper")
			}
		} footer: {
			Text(.localized("Clears the storage options above straight away. Nothing installed on your device is ever touched."))
		}
	}

	@ViewBuilder
	private var _lastRunSection: some View {
		Section {
			LabeledContent(.localized("Last Cleanup")) {
				if let date = _manager.lastRunDate {
					Text(verbatim: "\(date.formatted(date: .abbreviated, time: .shortened)) · \(_manager.lastFreedBytes.formattedFileSize)")
				} else {
					Text(.localized("Never"))
						.foregroundStyle(.secondary)
				}
			}
		}
	}
}

// MARK: - Actions
extension CleanupView {
	private func _clean() {
		_isCleaning = true
		NBHaptic.tap()

		let summary = _manager.cleanNow()

		if summary.isIdle {
			Toast.info(.localized("Nothing to clean up"), systemImage: "checkmark.circle")
		}

		Task {
			await _refreshReclaimable()
			_isCleaning = false
		}
	}

	private func _refreshReclaimable() async {
		let bytes = _manager.reclaimableBytes()
		await MainActor.run { _reclaimable = bytes }
	}
}
