//
//  AppDelegate.swift
//  ScreenBroadcaster
//
//  Created by Admin on 9/20/19.
//  Copyright © 2019 Admin. All rights reserved.
//

import UIKit
import StoreKit
import VideoToolbox
import IQKeyboardManagerSwift

enum IAP_Items: String {
    case all_once
}

var inAppPurchaseHandler = InAppPurchaseHandler()

let kIsIAPPurchased  = "isIAPPurchased"
let kDisplayTrialMessage = "displayTrialMessage"
let kIsBroadcastingInitiated = "isBroadcastingInitiated"

//Put Group Bundle Identifier Here
//let kUserDefaultsSuitName  = "group.com.app.screen"

//Put Service Bundle Identifier Here
//let kPrefferedExtenstion  = "com.app.screen.service"
let kPrefferedExtenstion  = "com.math.BroadcasterHandler.BroadcastUploadExtension"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    static var shared: AppDelegate? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.shouldResignOnTouchOutside = true

        self.launchMainVC()
        //self.setUpInitializationPoint()
        self.setUpAppStorePurchase()
        SKStoreReviewController.requestReview()
        UIApplication.shared.isIdleTimerDisabled = true
        
        startServer()

        return true
    }
    
    func launchMainVC() {
        // get storyboard instance
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MainController")

        // initialize window object
        self.window = UIWindow(frame: UIScreen.main.bounds)

        // navigation controller
        let nav1 = UINavigationController()

        // put MirroringController in navigation controller
        nav1.viewControllers = [vc]
        // make nav controller rootviewcontrooler
        self.window!.rootViewController = nav1
        self.window?.makeKeyAndVisible()
    }


    func setUpAppStorePurchase() {
        if !Session.restore() {
            print("app did not restore data from local storage")
            Session.setCurrent(session: Session())
        } else {
            // refresh
            Session.current().isRestored = true
            print("app did restore data from local storage")
        }
        // Attach an observer to the payment queue.
        SKPaymentQueue.default().add(StoreObserver.shared)
        // Fetch product information.
        inAppPurchaseHandler.fetchProductInformation()
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
//        DispatchQueue.global(qos: .background).async {
//            print("In background")
//            MirroringController.shared?.startServer()
//        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        MirroringController.shared?.startServer()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
        stopServer()
    }
    
    public var server: HttpServer?
    
    var count : Int32 = 0
    let session: UnsafeMutablePointer<VTCompressionSession?> = UnsafeMutablePointer<VTCompressionSession?>.allocate(capacity: 1)
    var lastSampleTime : CMTime?
    var m_nMirrorWidth = 0
    var m_nMirrorHeight = 0

    func startServer() {
         do {
             let server = CaptureServer()
             try server.start(80)
             self.server = server

             print("Http Server is Started")
         } catch {
             print("Server start error: \(error)")
         }
    }

    func stopServer() {
        self.server?.stop()
    }
}

