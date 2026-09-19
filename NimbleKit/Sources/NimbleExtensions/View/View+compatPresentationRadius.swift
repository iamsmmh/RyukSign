//
//  View+compatPresentationRadius.swift
//  VexSign
//
//  Created by iamsmmh on 16.04.2025.
//

import SwiftUI

extension View {
	@ViewBuilder
	public func compatPresentationRadius(_ cornerRadius: CGFloat?) -> some View {
		if #available(iOS 16.4, *) {
			self.presentationCornerRadius(cornerRadius)
		} else {
			self
		}
	}
}
