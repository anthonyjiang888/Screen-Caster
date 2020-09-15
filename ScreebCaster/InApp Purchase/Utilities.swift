/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Provides the Purchases view's data source and creates an alert.
*/

import StoreKit
#if os (macOS)
import Cocoa
#else
import UIKit
#endif

class Utilities {

	// MARK: - Properties

	/// Indicates whether the user has initiated a restore.
	var restoreWasCalled: Bool

	/// - returns: An array that will be used to populate the Purchases view.
	var dataSourceForPurchasesUI: [Section] {
		var dataSource = [Section]()
		let purchased = StoreObserver.shared.purchased
		let restored = StoreObserver.shared.restored

		if restoreWasCalled && (!restored.isEmpty) && (!purchased.isEmpty) {
			dataSource.append(Section(type: .purchased, elements: purchased))
			dataSource.append(Section(type: .restored, elements: restored))
		} else if restoreWasCalled && (!restored.isEmpty) {
			dataSource.append(Section(type: .restored, elements: restored))
		} else if !purchased.isEmpty {
			dataSource.append(Section(type: .purchased, elements: purchased))
		}

		/*
		Only want to display restored products when the "Restore" button(iOS), "Store > Restore" (macOS), or "Restore all restorable purchases"
		(tvOS) was tapped and there are restored products.
		*/
		restoreWasCalled = false
		return dataSource
	}

	// MARK: - Initialization

	init() {
		restoreWasCalled = false
	}

	// MARK: - Create Alert

	#if os (iOS) || os (tvOS)
	/// - returns: An alert with a given title and message.
	func alert(_ title: String, message: String, handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertController {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
		let action = UIAlertAction(title: NSLocalizedString(Messages.okButton, comment: Messages.emptyString),
								   style: .default, handler: handler)
		alertController.addAction(action)
		return alertController
	}
	#endif
}
