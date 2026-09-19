//
//  UIApplication+open.swift
//  NimbleKit
//
//  Created by iamsmmh on 30.04.2025.
//

import UIKit.UIApplication

extension UIApplication {
	static public func open(_ url: URL) {
		Self.shared.open(url, options: [:])
	}
	
	static public func open(_ urlString: String) {
		Self.shared.open(URL(string: urlString)!, options: [:])
	}
}
