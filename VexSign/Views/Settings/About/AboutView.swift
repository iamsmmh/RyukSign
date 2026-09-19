//
//  AboutView.swift
//  VexSign
//
//  Created by iamsmmh on 19.09.2026.
//

import SwiftUI
import NimbleViews

// MARK: - Extension: Model
extension AboutView {
	struct CreditsModel: Codable, Hashable {
		let name: String?
		let desc: String?
		let github: String
	}
}

// MARK: - View
struct AboutView: View {
	private let _credits: [CreditsModel] = [
		.init(name: "iamsmmh", desc: "Lead Developer — VexSign", github: "iamsmmh"),
		.init(name: "VexSign Team", desc: "Core Contributors", github: "iamsmmh"),
		.init(name: "Samara", desc: "Original Architecture", github: "claration"),
	]

	private let _sourceURL = "https://github.com/iamsmmh/VexSign"
	private let _licenseURL = "https://github.com/iamsmmh/VexSign/blob/main/LICENSE"
	private let _authorURL = "https://github.com/iamsmmh"

	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
			Section {
				VStack(spacing: 8) {
					FRAppIconView(size: 80)

					Text("VexSign")
						.font(.largeTitle)
						.bold()
						.foregroundStyle(Color.accentColor)

					Text("by @iamsmmh")
						.font(.headline)
						.foregroundStyle(.secondary)

					HStack(spacing: 4) {
						Text(.localized("Version"))
						Text(Bundle.main.version)
					}
					.font(.footnote)
					.foregroundStyle(.secondary)

					Text("The most powerful on-device signer")
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.top, 2)
				}
			}
			.frame(maxWidth: .infinity)
			.listRowBackground(EmptyView())

			NBSection("Why VexSign?") {
				VStack(alignment: .leading, spacing: 8) {
					Label("IPA Explorer — Edit inside IPA", systemImage: "folder.badge.gearshape")
					Label("File Transfer Server — HTTP/WebDAV", systemImage: "antenna.radiowaves.left.and.right")
					Label("Live Activities & Dynamic Island", systemImage: "sparkles")
					Label("Auto Cleanup Pipeline", systemImage: "wand.and.stars")
					Label("Batch Signing & Update All", systemImage: "square.stack.3d.up.fill")
					Label("Backup & Restore (.vexbackup)", systemImage: "externaldrive.connected.to.line.below")
				}
				.font(.subheadline)
				.foregroundStyle(.secondary)
			} footer: {
				Text("Exclusive features added by @iamsmmh — not available in Feather, ESign or Scarlet.")
			}

			NBSection(.localized("Credits")) {
				ForEach(_credits, id: \.github) { credit in
					_credit(name: credit.name, desc: credit.desc, github: credit.github)
				}
			}

			NBSection(.localized("Source & License")) {
				Button {
					UIApplication.open(_authorURL)
				} label: {
					Label("Author: @iamsmmh", systemImage: "person.crop.circle.fill")
				}
				Button(.localized("Source Code"), systemImage: "chevron.left.forwardslash.chevron.right") {
					UIApplication.open(_sourceURL)
				}
				Button(.localized("License (GPL-3.0)"), systemImage: "doc.text") {
					UIApplication.open(_licenseURL)
				}
			} footer: {
				Text("VexSign by @iamsmmh — Free software under GPL-3.0. Built with passion for power users. Star the repo if you like it!")
			}
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String?,
		desc: String?,
		github: String
	) -> some View {
		Button {
			UIApplication.open("https://github.com/\(github)")
		} label: {
			HStack {
				FRIconCellView(
					title: name ?? github,
					subtitle: desc ?? "",
					iconUrl: URL(string: "https://github.com/\(github).png")!,
					size: 45,
					isCircle: true
				)

				Image(systemName: "arrow.up.right")
					.foregroundColor(.secondary.opacity(0.65))
			}
		}
	}
}
