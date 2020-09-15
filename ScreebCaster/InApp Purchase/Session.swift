//
//  Session.swift
//  Raymond_IAP
//
//  Created by vedran on 25/11/2019.
//  Copyright © 2019 vedran. All rights reserved.
//

import UIKit
import StoreKit

class Session: NSObject, NSCoding {

    static private var restoreKeyName = "v1.0.d/Session"
    static private var sessionCurrent = Session()

    class Key {
        static let states = "states"
        static let purchasedOrRestored = "purchasedOrRestored"
    }

    // MARK: app custom data

    // MARK: variables for image placement
    var isRestored: Bool?

    var states: [String:SectionType] = [:]
    var purchasedOrRestored: [String:Bool] = [:]

    init(copyOf session: Session? = nil) {
        super.init()
        self.apply(session: session)
    }

    required convenience init(coder aDecoder: NSCoder) {

        self.init()

        if let stateStrings = aDecoder.decodeObject(forKey: Key.states) as? [String: String] {

            states = stateStrings.mapValues { SectionType(rawValue: $0) ?? .invalidProductIdentifiers }
//            print("dencoded states \(states)")
        }

        purchasedOrRestored = aDecoder.decodeObject(forKey: Key.purchasedOrRestored) as? [String: Bool] ?? [:]
    }

    func encode(with aCoder: NSCoder) {
//                print("encode states \(states)")
        aCoder.encode(states.mapValues { $0.rawValue }, forKey: Key.states)
        aCoder.encode(purchasedOrRestored, forKey: Key.purchasedOrRestored)

    }

    class func current() -> Session {

        return sessionCurrent
    }

    class internal func setCurrent(session: Session) {

        sessionCurrent = session
    }

    class internal func restore() -> Bool {

        if let
            archivedViewData = UserDefaults.standard.object(forKey: restoreKeyName) as? NSData,
            let session = NSKeyedUnarchiver.unarchiveObject(with: archivedViewData as Data) as? Session
        {

            sessionCurrent = session

            return true

        } else {

            return false
        }
    }

    class internal func archive() {

        DispatchQueue.global().async(execute: {

            let data = NSKeyedArchiver.archivedData(withRootObject: sessionCurrent)

            DispatchQueue.main.async(execute: {

                UserDefaults.standard.set(data, forKey: restoreKeyName)
                UserDefaults.standard.synchronize()

                NSLog(String(format: "stored local database list %.2f KB", Double(data.count)/(1024.0)))
            })
        })
    }


    func apply(session: Session?) {
    }

}
