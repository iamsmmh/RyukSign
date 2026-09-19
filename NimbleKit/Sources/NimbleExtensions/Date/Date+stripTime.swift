//
//  Date+stripTime.swift
//  VexSign
//
//  Created by VexSign TeamSign Team on 21.06.2025.
//

import Foundation.NSDate

extension Date {
	public func stripTime() -> Date {
		Calendar.current.startOfDay(for: self)
	}
}
