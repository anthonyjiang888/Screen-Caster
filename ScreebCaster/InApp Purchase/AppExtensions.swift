/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Creates extensions for the DateFormatter, ProductIdentifiers, Section, SKDownload, and SKProduct classes. Extends NSView and UIView to the
DiscloseView protocol. Extends UIBarButtonItem to conform to the EnableItem protocol.
*/

#if os (macOS)
import Cocoa
#elseif os (iOS)
import UIKit
#endif
import Foundation
import StoreKit

// MARK: - DateFormatter

extension DateFormatter {
	/// - returns: A string representation of date using the short time and date style.
	class func short(_ date: Date) -> String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .short
		return dateFormatter.string(from: date)
	}

	/// - returns: A string representation of date using the long time and date style.
	class func long(_ date: Date) -> String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .long
		return dateFormatter.string(from: date)
	}
}

// MARK: - Section

extension Section {
	/// - returns: A Section object matching the specified name in the data array.
	static func parse(_ data: [Section], for type: SectionType) -> Section? {
		let section = (data.filter({ (item: Section) in item.type == type }))
		return (!section.isEmpty) ? section.first : nil
	}
}

// MARK: - SKProduct
extension SKProduct {
	/// - returns: The cost of the product formatted in the local currency.
	var regularPrice: String? {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.locale = self.priceLocale
		return formatter.string(from: self.price)
	}
}

// MARK: - SKDownload

extension SKDownload {
	/// - returns: A string representation of the downloadable content length.
	var downloadContentSize: String {
		#if os (macOS)
		return ByteCountFormatter.string(fromByteCount: Int64(truncating: self.contentLength), countStyle: .file)
		#else
		return ByteCountFormatter.string(fromByteCount: self.contentLength, countStyle: .file)
		#endif
	}
}

// MARK: - DiscloseView

#if os (macOS)
extension NSView: DiscloseView {
	/// Show the view.
	func show() {
		self.isHidden = false
	}

	/// Hide the view.
	func hide() {
		self.isHidden = true
	}
}
#else
extension UIView: DiscloseView {
	/// Show the view.
	func show() {
		self.isHidden = false
	}

	/// Hide the view.
	func hide() {
		self.isHidden = true
	}
}

#endif
