//
//  Persistence.swift
//  VexSign
//
//  Created by VexSign Team on 10.04.2025.
//  Maintained by @iamsmmh — https://github.com/iamsmmh/VexSign
//

import CoreData
import Foundation
import OSLog

// MARK: - Storage
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer

	private let _name: String = "VexSign"
	private let _legacyName: String = "Feather" // For migration from old installs

	init(inMemory: Bool = false) {
		// Migrate legacy store file if exists (Feather.sqlite -> VexSign.sqlite) to preserve user data
		if !inMemory {
			Self._migrateLegacyStoreIfNeeded()
		}

		container = NSPersistentContainer(name: _name)

		if inMemory {
			container.persistentStoreDescriptions.first?.url =
				URL(fileURLWithPath: "/dev/null")
		}

		_loadPersistentStoreAggressively()
		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		_migrateSortIndexIfNeeded()
	}
	
	var context: NSManagedObjectContext {
		container.viewContext
	}
	
	func saveContext() {
		// Save sync if already on main to avoid a deadlock
		if Thread.isMainThread {
			if context.hasChanges {
				do {
					try context.save()
				} catch {
					Logger.misc.error("CoreData save failed: \(error.localizedDescription)")
				}
			}
		} else {
			DispatchQueue.main.async {
				if self.context.hasChanges {
					do {
						try self.context.save()
					} catch {
						Logger.misc.error("CoreData save failed: \(error.localizedDescription)")
					}
				}
			}
		}
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: (request as? NSFetchRequest<NSFetchRequestResult>)!)
		_ = try? context.execute(deleteRequest)
	}
	
	func countContent<T: NSManagedObject>(for type: T.Type) -> String {
		let request = T.fetchRequest()
		return "\((try? context.count(for: request)) ?? 0)"
	}

	private static func _migrateLegacyStoreIfNeeded() {
		let fm = FileManager.default
		guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
		let legacyBase = appSupport.appendingPathComponent("Feather.sqlite")
		let newBase = appSupport.appendingPathComponent("VexSign.sqlite")
		
		if fm.fileExists(atPath: newBase.path) { return }
		if !fm.fileExists(atPath: legacyBase.path) { return }
		
		let legacyFiles = [
			legacyBase,
			legacyBase.deletingPathExtension().appendingPathExtension("sqlite-wal"),
			legacyBase.deletingPathExtension().appendingPathExtension("sqlite-shm")
		]
		let newFiles = [
			newBase,
			newBase.deletingPathExtension().appendingPathExtension("sqlite-wal"),
			newBase.deletingPathExtension().appendingPathExtension("sqlite-shm")
		]
		
		for (oldFile, newFile) in zip(legacyFiles, newFiles) {
			if fm.fileExists(atPath: oldFile.path) {
				try? fm.moveItem(at: oldFile, to: newFile)
			}
		}
	}

	private func _loadPersistentStoreAggressively() {
		container.loadPersistentStores { description, error in
			if error != nil {
				self._destroyStore(at: description.url)
				self.container.loadPersistentStores { _, error in
					if let error {
						fatalError("Core Data unrecoverable: \(error)")
					}
				}
			}
		}
	}

	// Backfills sortIndex from the old date-desc order so manual reordering starts stable
	private func _migrateSortIndexIfNeeded() {
		let key = "vexsign.sortIndexMigrated"
		guard !UserDefaults.standard.bool(forKey: key) else { return }

		let signedRequest: NSFetchRequest<Signed> = Signed.fetchRequest()
		signedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
		if let apps = try? context.fetch(signedRequest) {
			for (index, app) in apps.enumerated() { app.sortIndex = Int32(index) }
		}

		let importedRequest: NSFetchRequest<Imported> = Imported.fetchRequest()
		importedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
		if let apps = try? context.fetch(importedRequest) {
			for (index, app) in apps.enumerated() { app.sortIndex = Int32(index) }
		}

		saveContext()
		UserDefaults.standard.set(true, forKey: key)
	}

	private func _destroyStore(at url: URL?) {
		guard let url else { return }

		let base = url.deletingPathExtension()
		let fm = FileManager.default

		let files = [
			base.appendingPathExtension("sqlite"),
			base.appendingPathExtension("sqlite-wal"),
			base.appendingPathExtension("sqlite-shm")
		]

		for file in files {
			try? fm.removeItem(at: file)
		}

		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.signed)
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.unsigned)
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.certificates)
		UserDefaults.standard.set(0, forKey: "vexsign.selectedCert")
	}
}
