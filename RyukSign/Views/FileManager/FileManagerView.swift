//
//  FileManagerView.swift
//  RyukSign
//
//  In-app Files browser for the app's Documents container (KSign-style):
//  browse, open text files in an editor, share, create, rename, delete.
//  Rooted at Documents so it only ever shows RyukSign's own files — the same
//  container exposed through Files → RyukSign, Web Manager, and backups.
//

import SwiftUI
import UIKit
import NimbleViews
import NimbleExtensions

// MARK: - Root view
struct FileManagerView: View {
	@State private var _path: [URL] = []

	var body: some View {
		NavigationStack(path: $_path) {
			_DirectoryContent(url: FileManagerModel.root, onUp: { _path.removeLast() })
				.navigationDestination(for: URL.self) { url in
					_DirectoryContent(url: url, onUp: { _path.removeLast() })
				}
		}
	}
}

// MARK: - Directory level
private struct _DirectoryContent: View {
	@StateObject private var _model: FileManagerModel
	private let _onUp: () -> Void

	@State private var _isNamingPresenting = false
	@State private var _namingKind: NamingKind = .file
	@State private var _newName = ""
	@State private var _renameTarget: FileManagerModel.Item?
	@State private var _editingItem: FileManagerModel.Item?

	enum NamingKind { case file, folder }

	init(url: URL, onUp: @escaping () -> Void) {
		_model = StateObject(wrappedValue: FileManagerModel(url: url))
		_onUp = onUp
	}

	private static let _sizeFormatter: ByteCountFormatter = {
		let f = ByteCountFormatter()
		f.countStyle = .file
		return f
	}()

	private static let _dateFormatter: RelativeDateTimeFormatter = {
		let f = RelativeDateTimeFormatter()
		f.unitsStyle = .short
		return f
	}()

	// MARK: Body
	var body: some View {
		List {
			ForEach(_model.items) { item in
				if item.isDirectory {
					NavigationLink(value: item.url) {
						_row(for: item, showsChevron: true)
					}
					.contextMenu { _contextMenu(for: item) }
				} else {
					Button {
						_open(item)
					} label: {
						_row(for: item, showsChevron: false)
					}
					.contextMenu { _contextMenu(for: item) }
				}
			}
		}
		.listStyle(.insetGrouped)
		.navigationTitle(_model.isRoot ? .localized("Documents") : _model.currentURL.lastPathComponent)
		.navigationBarTitleDisplayMode(.inline)
		.refreshable { _model.load() }
		.overlay {
			if !_model.isLoading && _model.items.isEmpty {
				Text(.localized("Empty folder"))
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.toolbar {
			ToolbarItemGroup(placement: .topBarTrailing) {
				Menu {
					Button(.localized("New File"), systemImage: "doc.badge.plus") {
						_namingKind = .file
						_isNamingPresenting = true
					}
					Button(.localized("New Folder"), systemImage: "folder.badge.plus") {
						_namingKind = .folder
						_isNamingPresenting = true
					}
				} label: {
					Image(systemName: "plus")
				}

				Button(.localized("Share"), systemImage: "square.and.arrow.up") {
					UIActivityViewController.show(activityItems: [_model.currentURL])
				}
			}

			if _model.canGoUp {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						_onUp()
					} label: {
						Image(systemName: "arrow.up")
					}
					.accessibilityLabel(.localized("Up"))
				}
			}
		}
		.alert(
			_namingKind == .file ? .localized("New File") : .localized("New Folder"),
			isPresented: $_isNamingPresenting
		) {
			TextField(.localized("Name"), text: $_newName)
			Button(.localized("Cancel"), role: .cancel) { _newName = "" }
			Button(.localized("Create")) {
				let succeeded = _namingKind == .file
					? _model.createFile(named: _newName)
					: _model.createFolder(named: _newName)
				_newName = ""
				if !succeeded {
					Toast.error(.localized("Couldn't create that name here"), duration: .long)
				}
			}
		}
		.alert(.localized("Rename"), isPresented: Binding(
			get: { _renameTarget != nil },
			set: { if !$0 { _renameTarget = nil } }
		)) {
			TextField(.localized("New Name"), text: $_newName)
			Button(.localized("Cancel"), role: .cancel) { _renameTarget = nil; _newName = "" }
			Button(.localized("Rename")) {
				if let target = _renameTarget {
					let succeeded = _model.rename(target, to: _newName)
					if !succeeded {
						Toast.error(.localized("Couldn't rename that"), duration: .long)
					}
				}
				_renameTarget = nil
				_newName = ""
			}
		}
		.sheet(item: $_editingItem) { item in
			TextFileEditorView(url: item.url)
		}
		.onAppear { _model.load() }
	}

	// MARK: Actions

	private func _open(_ item: FileManagerModel.Item) {
		if FileManagerModel.isTextFile(item.url) {
			_editingItem = item
		} else {
			UIActivityViewController.show(activityItems: [item.url])
		}
	}

	@ViewBuilder
	private func _contextMenu(for item: FileManagerModel.Item) -> some View {
		if !item.isDirectory {
			Button(.localized("Share"), systemImage: "square.and.arrow.up") {
				UIActivityViewController.show(activityItems: [item.url])
			}
			if FileManagerModel.isTextFile(item.url) {
				Button(.localized("Edit"), systemImage: "pencil") {
					_editingItem = item
				}
			}
		}
		Button(.localized("Rename"), systemImage: "pencil.circle") {
			_newName = item.name
			_renameTarget = item
		}
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			DestructiveConfirm.present(
				title: .localized("Delete \(item.name)"),
				message: .localized("Removes it and everything inside it from RyukSign's Documents.")
			) {
				if !_model.delete(item) {
					Toast.error(.localized("Couldn't delete that"), duration: .long)
				}
			}
		}
	}

	// MARK: Row

	private func _row(for item: FileManagerModel.Item, showsChevron: Bool) -> some View {
		HStack(spacing: 12) {
			Image(systemName: _icon(for: item))
				.font(.title3)
				.foregroundStyle(item.isDirectory ? Color.accentColor : .secondary)
				.frame(width: 28)

			VStack(alignment: .leading, spacing: 2) {
				Text(item.name)
					.lineLimit(2)
				if !item.isDirectory {
					Text(_subtitle(for: item))
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}

			if showsChevron {
				Spacer()
				Image(systemName: "chevron.forward")
					.font(.caption)
					.foregroundStyle(.tertiary)
			}
		}
		.contentShape(Rectangle())
	}

	private func _icon(for item: FileManagerModel.Item) -> String {
		if item.isDirectory { return "folder.fill" }

		switch item.url.pathExtension.lowercased() {
		case "ipa", "tipa", "zip", "ar": return "archivebox.fill"
		case "p12": return "key.fill"
		case "mobileprovision", "entitlements": return "checkmark.seal.fill"
		case "dylib", "deb", "framework": return "wrench.and.screwdriver.fill"
		case "log", "txt": return "doc.text.fill"
		case "json", "plist", "xml", "mobileconfig": return "curlybraces"
		default: return "doc.fill"
		}
	}

	private func _subtitle(for item: FileManagerModel.Item) -> String {
		var parts: [String] = []
		if item.size > 0 {
			parts.append(Self._sizeFormatter.string(fromByteCount: item.size))
		}
		if let modified = item.modified {
			parts.append(Self._dateFormatter.localizedString(for: modified, relativeTo: Date()))
		}
		return parts.joined(separator: " · ")
	}
}
