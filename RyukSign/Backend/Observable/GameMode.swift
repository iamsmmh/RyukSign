//
//  GameMode.swift
//  RyukSign
//
//  "Game Mode" (KSign-style): a global, user-facing switch that pauses background
//  activity — network downloads, auto signing, update checks, and the scheduled
//  background tasks — while the user plays a game, to save battery and data.
//
//  Deliberately distinct from the per-app `Options.gameMode` (which sets the
//  `GCSupportsGameMode` Info.plist key on a signed game). This one is a device-
//  level setting backed by UserDefaults so every service can check it without
//  touching the signing options.
//

import Foundation

enum GameMode {
	/// Persisted setting. Read with `isOn`, write only through `setEnabled(_:)`.
	static let key = "Feather.gameMode"

	/// Posted after `setEnabled(_:)` flips the switch.
	static let didChangeNotification = Notification.Name("RyukSign.GameModeDidChange")

	static var isOn: Bool {
		UserDefaults.standard.bool(forKey: key)
	}

	/// The single write path: persists the switch, logs it, and pauses/resumes
	/// the work it governs. UI toggles call this instead of writing the default
	/// directly so the side effects always run.
	static func setEnabled(_ enabled: Bool) {
		guard isOn != enabled else { return }

		UserDefaults.standard.set(enabled, forKey: key)
		FileLogger.log(
			enabled
			? "Game Mode enabled — downloads, auto sign, and update checks paused"
			: "Game Mode disabled — paused work resumed",
			category: "system"
		)

		// In-flight network downloads hold resume data, so pausing loses nothing;
		// resuming restarts them where they left off.
		if enabled {
			DownloadManager.shared.pauseAllDownloads()
		} else {
			DownloadManager.shared.resumeAllDownloads()
		}

		NotificationCenter.default.post(name: didChangeNotification, object: nil)
	}
}
