//
//  P12Cracker.swift
//  VexSign
//
//  Recovers passwords for PKCS#12 (.p12) certificate files using common dictionary
//  candidates, numeric PIN sequences, or custom wordlists.
//

import Foundation
import Security

@MainActor
final class P12Cracker: ObservableObject {
	static let shared = P12Cracker()

	@Published private(set) var isRunning = false
	@Published private(set) var progress: Double = 0.0
	@Published private(set) var currentCandidate: String = ""
	@Published private(set) var testedCount: Int = 0
	@Published private(set) var totalCount: Int = 0
	@Published private(set) var foundPassword: String?

	private var _cancelRequested = false

	/// Common passwords observed across signing services, leaks, and enterprise dumps.
	static let commonPasswords: [String] = [
		"", // Blank / no password
		"1",
		"12",
		"123",
		"1234",
		"12345",
		"123456",
		"12345678",
		"123456789",
		"1111",
		"0000",
		"password",
		"Password",
		"apple",
		"Apple",
		"cert",
		"Cert",
		"developer",
		"ios",
		"iOS",
		"test",
		"admin",
		"app",
		"signer",
		"vex",
		"vexsign",
		"esign",
		"ESign",
		"scarlet",
		"gbox",
		"GBox",
		"khoindvn",
		"hdwg",
		"applep12",
		"123123",
		"666666",
		"888888",
		"999999",
		"2023",
		"2024",
		"2025",
		"2026",
		"12344321",
		"qwerty",
		"abc123"
	]

	enum Mode: String, CaseIterable, Identifiable {
		case quickDictionary
		case numericPins
		case fullDictionary

		var id: String { rawValue }

		var title: String {
			switch self {
			case .quickDictionary: String.localized("Common Passwords")
			case .numericPins: String.localized("4-Digit PINs (0000-9999)")
			case .fullDictionary: String.localized("Combined Search")
			}
		}

		var count: Int {
			switch self {
			case .quickDictionary: P12Cracker.commonPasswords.count
			case .numericPins: 10000
			case .fullDictionary: P12Cracker.commonPasswords.count + 10000
			}
		}
	}

	/// Checks a single password against PKCS#12 data using Security framework.
	nonisolated static func verify(p12Data: Data, password: String) -> Bool {
		let options: [String: Any] = [
			kSecImportExportPassphrase as String: password
		]
		var rawItems: CFArray?
		let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)
		return status == errSecSuccess
	}

	func cancel() {
		_cancelRequested = true
		isRunning = false
	}

	/// Runs password recovery against a .p12 file.
	func crack(
		p12URL: URL,
		mode: Mode = .fullDictionary,
		customCandidates: [String] = []
	) async -> String? {
		guard let p12Data = try? Data(contentsOf: p12URL) else { return nil }
		return await crack(p12Data: p12Data, mode: mode, customCandidates: customCandidates)
	}

	func crack(
		p12Data: Data,
		mode: Mode = .fullDictionary,
		customCandidates: [String] = []
	) async -> String? {
		isRunning = true
		_cancelRequested = false
		foundPassword = nil
		testedCount = 0

		var candidates: [String] = []

		if !customCandidates.isEmpty {
			candidates.append(contentsOf: customCandidates)
		}

		switch mode {
		case .quickDictionary:
			candidates.append(contentsOf: Self.commonPasswords)
		case .numericPins:
			for i in 0...9999 {
				candidates.append(String(format: "%04d", i))
			}
		case .fullDictionary:
			candidates.append(contentsOf: Self.commonPasswords)
			for i in 0...9999 {
				candidates.append(String(format: "%04d", i))
			}
		}

		// De-duplicate while preserving order
		var seen = Set<String>()
		candidates = candidates.filter { seen.insert($0).inserted }

		totalCount = candidates.count
		progress = 0.0

		let batchSize = 50

		for chunkStart in stride(from: 0, to: candidates.count, by: batchSize) {
			if _cancelRequested {
				isRunning = false
				return nil
			}

			let chunkEnd = min(chunkStart + batchSize, candidates.count)
			let batch = Array(candidates[chunkStart..<chunkEnd])

			// Run this batch off the main actor
			let matched = await Task.detached(priority: .userInitiated) { () -> String? in
				for candidate in batch {
					if Self.verify(p12Data: p12Data, password: candidate) {
						return candidate
					}
				}
				return nil
			}.value

			testedCount = chunkEnd
			progress = Double(chunkEnd) / Double(max(1, candidates.count))
			currentCandidate = batch.last ?? ""

			if let matched {
				foundPassword = matched
				isRunning = false
				return matched
			}

			// Yield briefly so UI remains responsive
			await Task.yield()
		}

		isRunning = false
		return nil
	}
}
