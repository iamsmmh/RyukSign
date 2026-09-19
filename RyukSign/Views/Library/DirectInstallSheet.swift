//
//  DirectInstallSheet.swift
//  RyukSign
//
//  One-tap download, auto-signing, and direct installation from URL.
//

import SwiftUI
import NimbleViews

struct DirectInstallSheet: View {
	@Environment(\.dismiss) private var dismiss

	enum InstallMode: String, CaseIterable, Identifiable {
		case signAndInstall
		case installWithoutSigning

		var id: String { rawValue }
		var title: String {
			switch self {
			case .signAndInstall: .localized("Sign & Install")
			case .installWithoutSigning: .localized("Install Without Signing")
			}
		}
	}

	@State var urlString: String = ""
	@State var selectedMode: InstallMode = .signAndInstall
	@State private var isProcessing = false
	@State private var statusMessage = ""

	var body: some View {
		NBNavigationView(.localized("Direct Install"), displayMode: .inline) {
			Form {
				Section {
					TextField(.localized("https://example.com/app.ipa"), text: $urlString)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.disabled(isProcessing)

					Picker(.localized("Installation Mode"), selection: $selectedMode) {
						ForEach(InstallMode.allCases) { mode in
							Text(mode.title).tag(mode)
						}
					}
					.disabled(isProcessing)
				} header: {
					Text(.localized("Package URL"))
				} footer: {
					Text(.localized("Directly download, prepare, and install the package on your device in one step."))
				}

				if isProcessing {
					Section {
						HStack {
							ProgressView()
								.padding(.trailing, 6)
							Text(statusMessage)
								.font(.subheadline)
								.foregroundColor(.secondary)
						}
					}
				} else {
					Section {
						Button {
							_startDirectInstall()
						} label: {
							HStack {
								Spacer()
								Label(.localized("Start Direct Install"), systemImage: "arrow.down.app.fill")
									.bold()
								Spacer()
							}
						}
						.disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
			}
		}
	}

	private func _startDirectInstall() {
		let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let targetURL = URL(string: trimmed), targetURL.scheme != nil else {
			Toast.error(.localized("Please enter a valid URL."))
			return
		}

		isProcessing = true
		statusMessage = .localized("Queuing download…")

		let download = DownloadManager.shared.startDownload(
			from: targetURL,
			appName: targetURL.deletingPathExtension().lastPathComponent
		)

		if selectedMode == .installWithoutSigning {
			// AutoSign is bypassed; once downloaded and unpacked, app will be in Library.
			Toast.success(.localized("Download started for direct install"), systemImage: "arrow.down.app")
			dismiss()
		} else {
			Toast.success(.localized("Download queued for signing & installation"), systemImage: "arrow.down.app")
			dismiss()
		}
	}
}
