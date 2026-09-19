//
//  AboutView.swift
//  VexSign
//
//  Created by VexSign Team on 30.04.2025.
//  Maintained by @iamsmmh — https://github.com/iamsmmh/VexSign
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
		.init(name: "iamsmmh", desc: "Lead Developer — VexSign (Exclusive Features)", github: "iamsmmh"),
		.init(name: "Samara / @claration", desc: "Feather — Original Base Project (GPL-3.0)", github: "claration"),
		.init(name: "jkcoxson", desc: "idevice — AFC Installation Backend", github: "jkcoxson"),
		.init(name: "zhlynn", desc: "Zsign — On-Device Signing", github: "zhlynn"),
		.init(name: "tealbathingsuit", desc: "ElleKit — Tweak Injection", github: "tealbathingsuit"),
		.init(name: "kean", desc: "Nuke — Image Caching", github: "kean"),
		.init(name: "Lakr233", desc: "Asspp — HTTP Server Reference", github: "Lakr233"),
		.init(name: "nekohaxx", desc: "plistserver — Install Helper", github: "nekohaxx"),
		.init(name: "VexSign Team", desc: "Contributors & Translators", github: "iamsmmh"),
	]

	private let _sourceURL = "https://github.com/iamsmmh/VexSign"
	private let _featherURL = "https://github.com/claration/Feather"
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

			NBSection("Base Project — Feather") {
				VStack(alignment: .leading, spacing: 6) {
					Text("VexSign is built on top of Feather by @claration")
						.font(.subheadline)
						.bold()
					Text("Feather pioneered on-device signing on stock iOS. Without Feather, VexSign wouldn't exist. Special thanks to @claration for open sourcing GPL-3.0.")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Button {
					UIApplication.open(_featherURL)
				} label: {
					Label("Feather by @claration (Base)", systemImage: "arrow.triangle.branch")
				}
			} footer: {
				Text("Base features: Signing engine, CoreData model, UI architecture from Feather.")
			}

			NBSection("Exclusive by @iamsmmh") {
				VStack(alignment: .leading, spacing: 8) {
					Label("IPA Explorer — Edit inside IPA", systemImage: "folder.badge.gearshape")
					Label("File Transfer Server — HTTP/WebDAV", systemImage: "antenna.radiowaves.left.and.right")
					Label("Live Activities & Dynamic Island", systemImage: "sparkles")
					Label("Auto Cleanup Pipeline", systemImage: "wand.and.stars")
					Label("Batch Signing & Update All", systemImage: "square.stack.3d.up.fill")
					Label("Backup & Restore (.vexbackup)", systemImage: "externaldrive.connected.to.line.below")
					Label("Logs & File Manager", systemImage: "doc.text.magnifyingglass")
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
				Text("VexSign by @iamsmmh, based on Feather by @claration. Free software under GPL-3.0. Star the repo if you like it! Built with ❤️")
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
