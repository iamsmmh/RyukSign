//
//  AntiRevokeView.swift
//  RyukSign
//
//  Settings → Installation → Anti-Revoke: builds a per-device DNS profile that pins a
//  DNS-over-HTTPS resolver for Apple's revocation-check hosts. The user supplies the endpoint
//  (a sinkhole DoH they trust) because RyukSign ships no hosted service of its own.
//

import SwiftUI
import NimbleViews
import NimbleExtensions

// MARK: - View
struct AntiRevokeView: View {
	@State private var _endpoint = ""
	@State private var _isBuilding = false
	@State private var _lastBuiltURL: URL?

	private var _hasProfile: Bool { AntiRevokeManager.shared.profileURL != nil }
	private var _defaultEndpoint: String { "https://example.com/dns-query" }

	// MARK: Body
	var body: some View {
		NBList(.localized("Anti-Revoke")) {
			_statusSection
			_configSection
			_hostsSection
		}
	}

	@ViewBuilder
	private var _statusSection: some View {
		Section {
			LabeledContent(.localized("Status")) {
				Text(_hasProfile ? .localized("Ready to install") : .localized("Not protected"))
					.foregroundStyle(_hasProfile ? Color.green : Color.secondary)
			}
		} footer: {
			Text(.localized("iOS only installs DNS profiles from Settings, so the profile is shared for you to save and open there. It cannot un-revoke a certificate Apple has already revoked — it slows down future checks and keep a still-valid certificate working longer."))
		}
	}

	@ViewBuilder
	private var _configSection: some View {
		Section {
			TextField(.localized("DNS-over-HTTPS endpoint"), text: $_endpoint)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.keyboardType(.URL)

			Button {
				_build()
			} label: {
				if _isBuilding {
					HStack {
						ProgressView()
							.padding(.trailing, 2)
						Text(.localized("Building…"))
					}
				} else {
					Label(.localized("Generate Profile"), systemImage: "shield.lefthalf.filled")
				}
			}
			.disabled(_isBuilding)

			if let url = _lastBuiltURL ?? AntiRevokeManager.shared.profileURL {
				Button {
					AntiRevokeManager.shareProfile(url)
				} label: {
					Label(.localized("Share Profile"), systemImage: "square.and.arrow.up")
				}

				Button(role: .destructive) {
					AntiRevokeManager.shared.removeGeneratedProfile()
					_lastBuiltURL = nil
					Toast.success(.localized("Profile removed"), systemImage: "trash")
				} label: {
					Label(.localized("Delete Profile"), systemImage: "trash")
				}
			}
		} header: {
			Text(.localized("Resolver"))
		} footer: {
			Text(.localized("Point this at a DNS-over-HTTPS server that refuses to answer Apple's revocation hosts. Without a blocking resolver the profile does nothing — RyukSign runs no server of its own."))
		}
	}

	@ViewBuilder
	private var _hostsSection: some View {
		Section {
			ForEach(AntiRevokeManager.revocationHosts, id: \.self) { host in
				Text(host)
					.font(.system(.subheadline, design: .monospaced))
			}
		} header: {
			Text(.localized("Hosts to block"))
		} footer: {
			Text(.localized("Apple queries these hosts to check a certificate's status. A working anti-revoke resolver answers them with nothing, so the check cannot return \"revoked\"."))
		}
	}

	// MARK: Actions

	private func _build() {
		let raw = _endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
		let endpoint = raw.isEmpty ? "" : raw

		guard let url = URL(string: endpoint), url.scheme?.lowercased() == "https" else {
			Toast.error(.localized("Enter an https:// DNS-over-HTTPS endpoint."), duration: .sticky)
			return
		}

		_isBuilding = true
		Task {
			let result: Result<URL, Error> = await MainActor.run {
				do {
					let built = try AntiRevokeManager.shared.buildProfile(
						serverName: url.host ?? "Anti-Revoke",
						serverURL: endpoint
					)
					return .success(built)
				} catch {
					return .failure(error)
				}
			}

			_isBuilding = false
			switch result {
			case .success(let built):
				_lastBuiltURL = built
				Toast.success(.localized("Profile ready"), systemImage: "checkmark.seal")
			case .failure(let error):
				Toast.error(error.localizedDescription, duration: .sticky)
			}
		}
	}
}
