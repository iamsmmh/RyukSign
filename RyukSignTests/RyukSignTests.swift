//
//  RyukSignTests.swift
//  RyukSignTests
//
//  Created by Lakhan Lothiyi on 19/04/2025.
//

import XCTest
@testable import RyukSign
@testable import Esign
 
final class RyukSignTests: XCTestCase {

	func testRepoParsing() async throws {
		let repoDatas: [URL: Data] = try await withThrowingTaskGroup(of: (URL,Data).self, returning: [URL : Data].self) { group in
			for url in repoURLs {
				group.addTask {
					let (data, _) = try await URLSession.shared.data(from: url)
					return (url, data)
				}
			}
			
			var results: [URL: Data] = [:]
			for try await result in group {
				results[result.0] = result.1
			}
			
			return results
		}
		
		let decoder = JSONDecoder()
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		decoder.dateDecodingStrategy = .formatted(dateFormatter)
		
		var accumulated: [Repository] = []
		for (url, data) in repoDatas {
			do {
				let repo = try decoder.decode(Repository.self, from: data)
				accumulated.append(repo)
			} catch {
				XCTFail("Failed to decode repo data: \(error)\n\nFailed for \(url)\n\n======================================\n\n")
			}
		}
	}
	
	func testRepoDeobfuscation() async throws  {
		// theres multiple ways to obfuscate a list of strings, base64, other encryption, etc.
		// kravasign/maplesign use plain base64 to export repository "codes", newlines seperated
		// by `[K$]` and or `[M$]` (depending on what app you're currently using)
		
		// on the other hand Easy Sign (Esign) obfuscate their repository codes using more than
		// base64, more involved — they use an obfuscation key and technique
		
		// we need to handle both cases, base64 and the latter, first we can check if whats
		// pasted starts with `source[`, then go from there. All we need is a list of repositories
		// seperated with newlines.
		
		let code = obfuscatedKUrl
		
		func decodeBase64Format(_ code: String) -> Result<[String], RepositoryDeobfuscationError> {
			guard
				let data = Data(base64Encoded: code),
				let decodedString = String(data: data, encoding: .utf8)
			else {
				return .failure(.base64DecodingFailure)
			}
			
			var repositories: [String]
			if decodedString.contains("[K$]") {
				repositories = decodedString.components(separatedBy: "[K$]")
			} else if decodedString.contains("[M$]") {
				repositories = decodedString.components(separatedBy: "[M$]")
			} else {
				repositories = decodedString.components(separatedBy: .newlines)
			}
			
			repositories = repositories.map {
				$0.trimmingCharacters(in: .whitespacesAndNewlines)
			}.filter { !$0.isEmpty }

			return repositories.isEmpty
			? .failure(.emptyResult)
			: .success(repositories)
		}
		
		let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !trimmedCode.isEmpty else {
			return
		}
		
		if trimmedCode.hasPrefix("source[") {
			_ = eRepoDecrypt(input: code)
			return
		} else {
			_ = decodeBase64Format(trimmedCode)
			return
		}
	}
}

// MARK: - Log classification (Logs tab / activity log)

extension RyukSignTests {
	func testLogParserClassifiesErrors() {
		let error = LogParser.classify("ERROR: signing failed")
		XCTAssertEqual(error.kind, .error)
		XCTAssertEqual(error.text, "signing failed")

		let explicit = LogParser.classify("boom", level: .error)
		XCTAssertEqual(explicit.kind, .error)
	}

	func testLogParserClassifiesDetailAndSuccess() {
		let detail = LogParser.classify(">>> zsign 1.2.3")
		XCTAssertEqual(detail.kind, .detail)
		XCTAssertEqual(detail.text, "zsign 1.2.3")

		let success = LogParser.classify("Install succeeded", level: .success)
		XCTAssertEqual(success.kind, .success)
	}

	func testLogParserRoundTripsFileLines() {
		// The on-disk format must re-classify the same as the in-memory entries:
		// "ERROR:" prefix and ">>>" marker survive a write + parse cycle.
		let file = """
		2026-09-19T12:00:00Z [sign] ERROR: bad plist
		2026-09-19T12:00:01Z [sign] >>> zsign 1.2.3
		2026-09-19T12:00:02Z [download] Download finished: app.ipa
		"""
		let entries = LogParser.parseFile(file)
		XCTAssertEqual(entries.count, 3)
		XCTAssertEqual(entries[0].kind, .info)    // newest first
		XCTAssertEqual(entries[0].category, "download")
		XCTAssertEqual(entries[1].kind, .detail)
		XCTAssertEqual(entries[2].kind, .error)
	}
}

// MARK: - Game Mode

extension RyukSignTests {
	func testGameModeDefaultsOff() {
		let defaults = UserDefaults.standard
		defaults.removeObject(forKey: GameMode.key)
		XCTAssertFalse(GameMode.isOn)
	}
}

// MARK: - Anti-Revoke profile

extension RyukSignTests {
	func testAntiRevokeProfileStructure() throws {
		let data = AntiRevokeManager.profileData()
		XCTAssertFalse(data.isEmpty)

		let payload = try XCTUnwrap(
			try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
		)
		XCTAssertEqual(payload["PayloadType"] as? String, "Configuration")
		XCTAssertEqual(payload["PayloadIdentifier"] as? String, AntiRevokeManager.identifier)

		let content = try XCTUnwrap(payload["PayloadContent"] as? [[String: Any]])
		XCTAssertEqual(content.first?["PayloadType"] as? String, "com.apple.dns.settings")

		let dns = try XCTUnwrap(content.first?["PayloadContent"] as? [[String: Any]])
		let servers = try XCTUnwrap(dns.first?["ServerAddresses"] as? [String])
		XCTAssertTrue(servers.contains("1.1.1.1"))
		XCTAssertTrue(servers.contains("8.8.8.8"))
	}
}

let obfuscatedKUrl = "aHR0cHM6Ly9jZG4uYWx0c3RvcmUuaW8vZmlsZS9hbHRzdG9yZS9hcHBzLmpzb24="
let obfEUrl = "source[5GHxhb1U7Lc5jIMpumASbN2teg9dyK5EAazzwnfm1/gPKQPTWzcz/Gq3Njt97KapLNMztZCR3sHbMw/AMSpBsztQijHaOP/HgNtFseMyB1U=]"

let repoURLs: [URL] = [
	"https://cdn.altstore.io/file/altstore/apps.json",
].map { URL(string: $0)! }

enum RepositoryDeobfuscationError: Error {
	case invalidFormat
	case esignDecodingFailure
	case base64DecodingFailure
	case emptyResult
}
