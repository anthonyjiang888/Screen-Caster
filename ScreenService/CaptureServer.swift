//
//  DemoServer.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation
import UIKit
import Photos

let kUserDefaultsSuitName  = "group.math.BroadcastHandler"
let kMirrorMode  = "MirrorMode"
let kRootPath = "/a/a.htm"

var g_session: WebSocketSession?
var g_sessionList = Array<WebSocketSession>()
var g_angleList = Array<String>()
var g_readyList = Array<Bool>()
var g_timeList = Array<Double>()

var g_SignCode: String?


extension UIImage {

    func base64String() -> String {
        let imageData = self.pngData()
        return imageData!.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
    }

    func base64JpegString() -> String {
        return self.jpegData(compressionQuality: 0.7)!.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
    }

    func copyOriginalImage() -> UIImage {
        UIGraphicsBeginImageContext(self.size);
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();

        return newImage!
    }



    func jpegUInt8() -> [UInt8] {
        let data: Data = self.jpegData(compressionQuality: 0.7)!

        var array = [UInt8]()
        array.append(contentsOf: data)

        return array;
    }
}

public func sendImageToClient(image: UIImage){
//    let imageData = image.jpegData(compressionQuality: 0.7);
   g_session?.writeText("data:image/jpeg;base64, " + image.base64JpegString())
}

public func sendDataToClient(array: [UInt8]){
    lock.lock()
    for (index, session) in g_sessionList.enumerated() {
        session.writeBinary(array)
        print("Index = ", index, "Send Size = ", array.count)
    }
    lock.unlock()
}

public func sendBkgColorToClient(text: String){
    lock.lock()
    for (index, session) in g_sessionList.enumerated() {
        let message = "BkgColor:" + text
        session.writeText(message)
    }
    lock.unlock()
}

public func sendFontSizeToClient(text: String){
    lock.lock()
    for (index, session) in g_sessionList.enumerated() {
        let message = "FontSize:" + text
        session.writeText(message)
    }
    lock.unlock()
}

public func sendMessageViewToClient(text: String){
    lock.lock()
    for (index, session) in g_sessionList.enumerated() {
        let message = "MessageView:" + text
        session.writeText(message)
    }
    lock.unlock()
}

public func sendMessageToClient(text: String){
    lock.lock()
    for (index, session) in g_sessionList.enumerated() {
        let message = "Message:" + text
        session.writeText(message)
    }
    lock.unlock()
}

public func sendImage64ToClient(image: UIImage){
    lock.lock()
    for (index, session) in g_sessionList.enumerated() {
        session.writeText("Image:data:image/jpeg;base64, " + image.base64JpegString())
    }
    lock.unlock()
}

func sendImageAssetData(asset : PHAsset) {
    let options = PHImageRequestOptions()
    options.isSynchronous = true
    options.isNetworkAccessAllowed = true
    
     // retrieve the image for the first result
    PHImageManager.default().requestImage(
        for: asset,
        targetSize: PHImageManagerMaximumSize,
        contentMode: .aspectFill,
        options: options
    ) {
        image, info in
        
        if( image == nil )
        {
            return
        }

       sendImage64ToClient(image: image!)
    }
}

let lock = NSLock()

public func sendDataToClient(array: [Int8]) -> Int {
    let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName)
    let angle = userDefaults?.object(forKey: "orient") as! String

    var totalSize:Int = 0

    let curTime:Double = NSDate().timeIntervalSince1970
    lock.lock()
    for (index, session) in g_sessionList.enumerated() {
        if( angle != g_angleList[index] ) {
            let angle_info = "Rotate:" + angle
            session.writeText(angle_info)
            g_angleList[index] = angle
        }

        let gap = curTime - g_timeList[index]
        if( g_readyList[index] == true || gap > 10 ) {  // send ready or timeout
            g_readyList[index] = false
            g_timeList[index] = curTime

            session.writeBinary(array)

            totalSize = totalSize + array.count
            print("Index = ", index, "Send Size = ", array.count, "Time Interval = ", gap)
        }
        else {
            print("Not Ready = ", index)
        }
    }
    lock.unlock()
//    g_session?.writeBinary(array)

    return totalSize
}


private func createQRFromString(str: String) -> UIImage? {
    let stringData = str.data(using: .utf8)

    let filter = CIFilter(name: "CIQRCodeGenerator")
    filter?.setValue(stringData, forKey: "inputMessage")
    filter?.setValue("H", forKey: "inputCorrectionLevel")

    let qrImage: CIImage = filter!.outputImage!
    let scale = 400 / qrImage.extent.size.width

    let transformedImage = qrImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    let image = UIImage(
        ciImage: transformedImage,
        scale: 1.0,
        orientation: UIImage.Orientation.down
    )
    return image
}

public func sendSigninQRCode() {
    let curTime = NSDate().timeIntervalSince1970
    let strSignCode:String = String(format: "%f", curTime)

    let qrImg = createQRFromString(str: strSignCode)
    let image = qrImg!.copyOriginalImage()

    let array = image.jpegUInt8()

    g_session?.writeBinary(array)


    let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName)
    userDefaults?.set(false, forKey: "qr_code_ok")
    userDefaults?.set(strSignCode, forKey: "qr_code")
}

public func CaptureServer() -> HttpServer {

    let server = HttpServer()

    server["/"] = { .ok(.htmlBody("""
        """ + $0.path)) }

    let publicDir = Bundle.main.resourcePath!
    let files = shareFilesFromDirectory(publicDir)
    server["/a/:path"] = files
    server["/a/"] = files    // needed to serve index file at root level

    server["/websocket"] = websocket(text: { (session, text) in
//        session.writeText(text)
        for (index, element) in g_sessionList.enumerated() {
            if element == session {
                print("Ack = ", index)
                g_readyList[index] = true
            }
        }
    }, binary: { (session, binary) in
        session.writeBinary(binary)
    }, pong: { (_, _) in
        // Got a pong frame
    }, connected: { (session) in
//        g_session = session
        g_sessionList.append(session)
        g_angleList.append("")
        g_readyList.append(true)
        g_timeList.append(0)

//        sendSigninQRCode()
        print("Websocket is connected")
        // New client connected
    }, disconnected: { (session) in
        // Client disconnected
        g_session = nil
        lock.lock()
        for (index, element) in g_sessionList.enumerated() {
            if element == session {
                g_sessionList.remove(at: index)
                g_angleList.remove(at: index)
                g_readyList.remove(at: index)
                g_timeList.remove(at:index)
            }
        }
        lock.unlock()
        print("Websocket is disconnected")

    })



    return server
}
