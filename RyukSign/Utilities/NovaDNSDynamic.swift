//
//  NovaDNSDynamic.swift
//  RyukSign
//
//  Created by NovaDev404 on 24.02.2026.
//  Imported from NexStore for RyukSign with dynamic rule fetching.
//

import Foundation

public struct DynamicDNSRules: Codable, Sendable {
	public let version: Int
	public let lastUpdated: String?
	public let primaryEndpoint: String
	public let fallbackEndpoints: [String]?
	public let blockedHosts: [String]

	public static let `default` = DynamicDNSRules(
		version: 1,
		lastUpdated: "2026-09-19",
		primaryEndpoint: "https://dns.novadev.vip/dns-query",
		fallbackEndpoints: ["https://dns.adguard-dns.com/dns-query"],
		blockedHosts: [
			"ocsp.apple.com",
			"ocsp2.apple.com",
			"valid.apple.com",
			"certs.apple.com",
			"crl.apple.com",
			"crl.apple.com.akadns.net",
			"ocsp.apple.com.akadns.net"
		]
	)
}

public enum NovaDNSDynamic: Sendable {
	private static let defaultRuleURL = "https://api.novadev.vip/api/novadns-dynamic/rules.json"
	private static let cachedRulesKey = "RyukSign.dynamicDNSRulesCache"

	public static func sendRequest(endpoint: String) async {
		guard let url = URL(string: "https://api.novadev.vip/api/novadns-dynamic/\(endpoint)") else {
			return
		}
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		_ = try? await URLSession.shared.data(for: request)
	}

	/// Fetches the dynamic rules from a remote JSON endpoint. Falls back to cached or default rules.
	public static func fetchRules(from customURL: String? = nil) async -> DynamicDNSRules {
		let endpointString = (customURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
			? customURL!
			: defaultRuleURL

		guard let url = URL(string: endpointString) else {
			return loadCachedRules()
		}

		do {
			var request = URLRequest(url: url)
			request.timeoutInterval = 10.0
			let (data, response) = try await URLSession.shared.data(for: request)
			if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
				let rules = try JSONDecoder().decode(DynamicDNSRules.self, from: data)
				saveCachedRules(rules)
				return rules
			}
		} catch {
			// Fall back to cache or default on network error
		}

		return loadCachedRules()
	}

	public static func loadCachedRules() -> DynamicDNSRules {
		if let data = UserDefaults.standard.data(forKey: cachedRulesKey),
		   let rules = try? JSONDecoder().decode(DynamicDNSRules.self, from: data) {
			return rules
		}
		return .default
	}

	public static func saveCachedRules(_ rules: DynamicDNSRules) {
		if let data = try? JSONEncoder().encode(rules) {
			UserDefaults.standard.set(data, forKey: cachedRulesKey)
		}
	}
}
