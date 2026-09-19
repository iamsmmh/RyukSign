//
//  TextFileEditorView.swift
//  RyukSign
//
//  Minimal in-app editor for text files under Documents (KSign-style): open,
//  edit, save. Refuses files over 2 MB or that aren't valid UTF-8 rather than
//  risk clobbering binary data.
//

import SwiftUI
import UIKit
import NimbleExtensions

// MARK: - View
struct TextFileEditorView: View {
	let url: URL

	@State private var _text: String?
	@State private var _errorMessage: String?
	@Environment(\.dismiss) private var _dismiss

	private static let _maxEditableBytes: Int64 = 2 * 1024 * 1024

	// MARK: Body
	var body: some View {
		NavigationStack {
			Group {
				if let _errorMessage {
					Text(_errorMessage)
						.font(.footnote)
						.foregroundStyle(.secondary)
						.padding()
				} else if let _text {
					TextEditor(text: $_text)
						.font(.system(.footnote, design: .monospaced))
						.autocorrectionDisabled()
						.smartQuotesDisabled()
						.padding(8)
				} else {
					ProgressView()
				}
			}
			.navigationTitle(url.lastPathComponent)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItemGroup(placement: .topBarTrailing) {
					Button(.localized("Share"), systemImage: "square.and.arrow.up") {
						UIActivityViewController.show(activityItems: [url])
					}
					Button(.localized("Save")) {
						_save()
					}
					.disabled(_text == nil)
				}
			}
			.onAppear(perform: _load)
		}
	}

	// MARK: Loading / Saving

	private func _load() {
		guard
			let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
			let size = attributes[.size] as? Int64,
			size <= Self._maxEditableBytes
		else {
			_errorMessage = .localized("File is too large to edit (over 2 MB).")
			return
		}

		Task.detached {
			let loaded: String?
			if let data = try? Data(contentsOf: self.url) {
				loaded = String(data: data, encoding: .utf8)
			} else {
				loaded = nil
			}

			await MainActor.run {
				if let loaded {
					self._text = loaded
				} else {
					self._errorMessage = .localized("Couldn't read this file as text.")
				}
			}
		}
	}

	private func _save() {
		guard let _text else { return }

		do {
			try _text.write(to: url, atomically: true, encoding: .utf8)
			FileLogger.log("Saved: \(url.lastPathComponent)", category: "files")
			Toast.success(.localized("Saved"))
			_dismiss()
		} catch {
			Toast.error(error.localizedDescription, duration: .long)
		}
	}
}
