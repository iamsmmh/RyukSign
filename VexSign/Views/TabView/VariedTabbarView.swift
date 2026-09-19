//
//  VariedTabbarView.swift
//  VexSign
//
//  Created by VexSign TeamSign Team on 11.04.2025.
//
import SwiftUI

struct VariedTabbarView: View {
	init() {}
	
	var body: some View {
		if #available(iOS 18, *) {
			ExtendedTabbarView()
		} else {
			TabbarView()
		}
	}
}
