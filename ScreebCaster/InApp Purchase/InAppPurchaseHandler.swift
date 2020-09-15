//
//  InAppPurchaseHandler.swift
//  Raymond_IAP
//
//  Created by vedran on 27/11/2019.
//  Copyright © 2019 vedran. All rights reserved.
//

import Foundation
import StoreKit

class InAppPurchaseHandler {

    fileprivate enum Segment: Int {
        case products, purchases
    }

    fileprivate var utility = Utilities()
    let products: UpgradeToProController? = nil
    let purchases: UpgradeToProController? = nil

    var ui: UIViewController?
    var reload: ((_ data: [Section]) -> Void)?
    var handlePurchased: ((_ transaction: SKPaymentTransaction) -> Void)?
    var handleRestored: ((_ transaction: SKPaymentTransaction) -> Void)?

    init() {
        StoreManager.shared.delegate = self
        StoreObserver.shared.delegate = self
    }

    func attach(ui: UIViewController?) {
        self.ui = ui
    }

    // MARK: - Fetch Product Information

    /// Retrieves product information from the App Store.
    func fetchProductInformation() {
        // First, let's check whether the user is allowed to make purchases. Proceed if they are allowed. Display an alert, otherwise.
        if StoreObserver.shared.isAuthorizedForPayments {

            let identifiers = [IAP_Items.all_once.rawValue]
            if !identifiers.isEmpty {
                // Refresh the UI with identifiers to be queried.
                reload?([Section(type: .invalidProductIdentifiers, elements: identifiers)])

                // Fetch product information.
                StoreManager.shared.startProductRequest(with: identifiers)
            }
        } else {
            // Warn the user that they are not allowed to make purchases.
            alert(with: Messages.status, message: Messages.cannotMakePayments)
        }
    }


    // MARK: - Display Alert

    /// Creates and displays an alert.
    func alert(with title: String, message: String, handler: ((UIAlertAction) -> Void)? = nil) {
        print("Alert: \(title) \(message)")
        let alertController = utility.alert(title, message: message, handler: handler)
        ui?.present(alertController, animated: true, completion: nil)
    }

    // MARK: - Restore All Appropriate Purchases

    /// Called when tapping the "Restore" button in the UI.
    @IBAction func restore(_ sender: UIBarButtonItem) {
        // Calls StoreObserver to restore all restorable purchases.
        StoreObserver.shared.restore()
    }


    // MARK: - Handle Restored Transactions

    /// Handles successful restored transactions. Switches to the Purchases view.
    fileprivate func handleRestoredSucceededTransaction() {
        utility.restoreWasCalled = true

        // Refresh the Purchases view with the restored purchases.
        reload?(utility.dataSourceForPurchasesUI)
    }

}


// MARK: - StoreManagerDelegate

/// Extends UpgradeToProrController to conform to StoreManagerDelegate.
extension InAppPurchaseHandler: StoreManagerDelegate {
    func storeManagerDidReceiveResponse(_ response: [Section]) {
        // Switch to the Products view controller.
        reload?(response)
    }

    func storeManagerDidReceiveMessage(_ message: String) {
        alert(with: Messages.productRequestStatus, message: message)
    }
}

// MARK: - StoreObserverDelegate

/// Extends InAppPurchaseHandler to conform to StoreObserverDelegate.
extension InAppPurchaseHandler: StoreObserverDelegate {
    func handlePurchased(_ transaction: SKPaymentTransaction) {
        handlePurchased?(transaction)
    }

    func handleRestored(_ transaction: SKPaymentTransaction) {
        handleRestored?(transaction)
    }

    func storeObserverDidReceiveMessage(_ message: String) {
        alert(with: Messages.purchaseStatus, message: message)
    }

    func storeObserverRestoreDidSucceed() {
        handleRestoredSucceededTransaction()
    }
}
