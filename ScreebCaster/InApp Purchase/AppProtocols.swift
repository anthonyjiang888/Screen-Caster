/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Creates the DiscloseView, EnableItem, StoreManagerDelegate, and StoreObserverDelegate protocols that allow you to
show/hide UI elements, enable/disable UI elements, notifies a listener about restoring purchases, manage StoreManager operations,and
handle StoreObserver operations, respectively.
*/

import Foundation
import StoreKit

// MARK: - DiscloseView

protocol DiscloseView {
	func show()
	func hide()
}

// MARK: - EnableItem

protocol EnableItem {
	func enable()
	func disable()
}

// MARK: - StoreManagerDelegate

protocol StoreManagerDelegate: AnyObject {
	/// Provides the delegate with the App Store's response.
	func storeManagerDidReceiveResponse(_ response: [Section])

	/// Provides the delegate with the error encountered during the product request.
	func storeManagerDidReceiveMessage(_ message: String)
}

// MARK: - StoreObserverDelegate

protocol StoreObserverDelegate: AnyObject {
	/// Tells the delegate that the restore operation was successful.
	func storeObserverRestoreDidSucceed()

	/// Provides the delegate with messages.
	func storeObserverDidReceiveMessage(_ message: String)

    func handlePurchased(_ transaction: SKPaymentTransaction)

    func handleRestored(_ transaction: SKPaymentTransaction)
}
