//
//  AntiRevokeView.swift
//  RyukSign
//
//  Settings screen for the DNS anti-revoke profile (KSign / FlareStore-style).
//  See `AntiRevokeManager` for what the profile does and why the status is
//  best-effort.
//

import SwiftUI
import UIKit
import NimbleViews
import NimbleExtensions

// MARK: - View
struct AntiRevokeView: View {
	/// Local mirror of the best-effort flag; updated by this screen's actions.
	@State private var _installed: Bool = AntiRevokeManager.isInstalled
	@State private var _showRemoveInstructions = false

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Anti-Revoke")) {
			Form {
				Section {
					LabeledContent(.localized("DNS Profile")) {
						Text(_installed ? .localized("Installed") : .localized("Not Installed"))
							.foregroundStyle(_installed ? Color.green : Color.secondary)
					}
				} footer: {
					Text(.localized("Status is best-effort: iOS does not let apps verify a profile's installation, so it is set when you install and cleared when you confirm the removal below."))
				}

				Section {
					Button(.localized("Install DNS Profile"), systemImage: "antenna.radiowaves.left.and.right") {
						AntiRevokeManager.presentInstall()
						_installed = true
					}
					Button(.localized("Remove (manual)"), systemImage: "trash") {
						_showRemoveInstructions = true
					}
				} footer: {
					Text(.localized("Installing the profile points your device's DNS at 1.1.1.1 and 8.8.8.8, which do not serve Apple's revocation checks the way carrier defaults do, slowing the ~7 day revocation of signed apps. It changes the device-wide DNS servers only — no other network setting is touched. Pick \"Install Profile\" in the share sheet to finish in Settings."))
				}

				Section {
					Button(.localized("Share Profile File"), systemImage: "square.and.arrow.up") {
						_shareProfile()
					}
				} footer: {
					Text(.localized("Sends the generated .mobileconfig to another app or device, e.g. to re-install it later without re-entering the app."))
				}
			}
			.alert(
				.localized("Remove the Profile"),
				isPresented: $_showRemoveInstructions
			) {
				Button(.localized("Removed — Update Status")) {
					AntiRevokeManager.markRemoved()
					_installed = false
				}
				Button(.localized("Cancel"), role: .cancel) {}
			} message: {
				Text(.localized("Open Settings → \"Profiles & Device Management\" (older iOS: \"VPN & Device Management\"), select \"RyukSign Anti-Revoke DNS\" and tap Remove Profile, then confirm here to update the status."))
			}
		}
	}

	// MARK: Actions

	private func _shareProfile() {
		do {
			let url = try AntiRevokeManager.writeProfile()
			UIActivityViewController.show(activityItems: [url])
		} catch {
			FileLogger.error("Anti-revoke profile share failed: \(error.localizedDescription)", category: "antirevoke")
			Toast.error(.localized("Couldn't generate the DNS profile"), duration: .long)
		}
	}
}
