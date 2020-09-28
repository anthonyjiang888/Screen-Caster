import ReplayKit
import VideoToolbox
import MMWormhole

let kIsIAPPurchased  = "isIAPPurchased"
let kDisplayTrialMessage = "displayTrialMessage"
let kIsBroadcastingInitiated = "isBroadcastingInitiated"


class CustomHandler: RPBroadcastSampleHandler  {

    private var server: HttpServer?
    private let context = CIContext()
    private let hls_handler = CustomHandlerHLS()

    var intTimeStamp : TimeInterval = 0
    var isBroadcastingStarted : Bool = false
    var count : Int32 = 0
    let session: UnsafeMutablePointer<VTCompressionSession?>
        = UnsafeMutablePointer<VTCompressionSession?>.allocate(capacity: 1)
    var init_flag = false
    var trialImagePixelBuffer : CVPixelBuffer?
    var mirrorMode = "Websocket"

    var wormhole: MMWormhole = MMWormhole(
        applicationGroupIdentifier: "group.math.BroadcastHandler",
        optionalDirectory         : "screencaster"
    )


    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        super.broadcastStarted(withSetupInfo: setupInfo)
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        print("Broadcast is started")
        trialImagePixelBuffer = pixelBuffer(forImage: (UIImage.init(named: "freetrial")?.cgImage)!)
        intTimeStamp = Date().timeIntervalSince1970
        self.isBroadcastingStarted = true
        if let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName) {
            userDefaults.set(true, forKey: kIsBroadcastingInitiated)
            mirrorMode = userDefaults.string(forKey: kMirrorMode)!
        }
        if mirrorMode == "Websocket" {
            do {
                let server = CaptureServer()
                try server.start(81)
                self.server = server

                print("Http Server is Started")
            }
            catch {
                print("Server start error: \(error)")
            }
        }
        else {
            hls_handler.broadcastStarted(withSetupInfo: nil)
        }

        wormhole.passMessageObject("WORMHOLE_SCREENCASTER_STARTED" as NSCoding, identifier: "screencaster_started")
    }


    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
        print("broadcastPaused")
        if mirrorMode == "Websocket" {
        }
        else {
            hls_handler.broadcastPaused()
        }
        
    }


    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
        print("broadcastResumed")
        if mirrorMode == "Websocket" {
        }
        else {
            hls_handler.broadcastResumed()
        }
    }


    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        server?.stop()
        print("broadcastFinished")
        if let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName) {
            userDefaults.set(false, forKey: kIsBroadcastingInitiated)
        }
        
        if mirrorMode == "Websocket" {
        }
        else {
            hls_handler.broadcastFinished()
        }
        wormhole.passMessageObject("WORMHOLE_SCREENCASTER_STOPPED" as NSCoding, identifier: "screencaster_stopped")
    }


    func initCodec(imageBuffer: CVImageBuffer) {
        if init_flag == true {
            return
        }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        let defaultWidth = CGFloat(1200.0)
        let scale: CGFloat = defaultWidth / CGFloat(width)
        let fHeight = scale * CGFloat(height)

        print("Codec Init Start")
        VTCompressionSessionCreate(
            allocator: nil,
            width    : Int32(defaultWidth),
            height   : Int32(fHeight),
            codecType: kCMVideoCodecType_JPEG,
            encoderSpecification   : nil,
            imageBufferAttributes  : nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: session
        )

        print("Codec Init End")
        init_flag = true
    }


    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        if mirrorMode == "m3u8" {
            return hls_handler.processSampleBuffer(sampleBuffer, with: sampleBufferType)
        }
        
        switch sampleBufferType {
            case RPSampleBufferType.video:
                var isIAPPurchased = false
                if let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName) {
                    isIAPPurchased = userDefaults.bool(forKey: kIsIAPPurchased)
                }
                var imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                var pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) as CMTime
                if isIAPPurchased {
                    //imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                }
                else {
                    if self.isBroadcastingStarted {
                        if self.intTimeStamp + 60 < Date().timeIntervalSince1970 {
                            self.intTimeStamp = Date().timeIntervalSince1970
                            self.isBroadcastingStarted = false
                            if let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName) {
                                userDefaults.set(true, forKey: kDisplayTrialMessage)
                                userDefaults.synchronize()
                            }
                        }
                        else {
                            //imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                        }
                    }
                    else {
                        if self.intTimeStamp + 120 < Date().timeIntervalSince1970 {
                            self.intTimeStamp = Date().timeIntervalSince1970
                            self.isBroadcastingStarted = true
                        }
                        imageBuffer = trialImagePixelBuffer!
                    }
                }


                initCodec(imageBuffer:imageBuffer)

                let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName)

                if let orientationAttachment =  CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {

                    let orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value)

                    var orient = "0"
                    if orientation == CGImagePropertyOrientation.up {
                        orient = "0"
                    }
                    else if orientation == CGImagePropertyOrientation.right {
                        orient = "270"
                    }
                    else if orientation == CGImagePropertyOrientation.down {
                        orient = "180"
                    }
                    else if orientation == CGImagePropertyOrientation.left {
                        orient = "90"
                    }

                    userDefaults?.set(orient, forKey: "orient")
                }
                else {
                    userDefaults?.set("0", forKey: "orient")
                }

                VTCompressionSessionEncodeFrame(session.pointee!,
                    imageBuffer:imageBuffer,
                    presentationTimeStamp: pts,
                    duration: CMTime.invalid,
                    frameProperties: nil,
                    infoFlagsOut: nil
                ) { (status, infoFlags, sampleBuffer) in

                        guard status == noErr else {
                            print("error: \(status)")
                            return
                        }

                        if infoFlags == .frameDropped {
                            print("frame dropped")
                            return
                        }

                        guard let sampleBuffer = sampleBuffer else {
                            print("sampleBuffer is nil")
                            return
                        }

                        if CMSampleBufferDataIsReady(sampleBuffer) != true {
                            print("sampleBuffer data is not ready")
                            return
                        }

                        // handle frame data
                        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                            return
                        }

                        var lengthAtOffset: Int = 0
                        var totalLength: Int = 0
                        var dataPointer: UnsafeMutablePointer<Int8>?
                        if CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr {
                            let intArray = Array(UnsafeBufferPointer(start: dataPointer, count: totalLength))
                            //let uintArray = intArray.map { UInt8(bitPattern: $0) }
                            sendDataToClient(array: intArray)
                        }
                    }

                break
            case RPSampleBufferType.audioApp:
                // Handle audio sample buffer for app audio
                //broadcaster.appendSampleBuffer(sampleBuffer, withType: .audio)
                break
            case RPSampleBufferType.audioMic:
                // Handle audio sample buffer for mic audio
                break
            default: break
        }
    }


    func pixelBuffer (forImage image:CGImage) -> CVPixelBuffer? {
        let frameSize = CGSize(width: image.width, height: image.height)

        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)

        if status != kCVReturnSuccess {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        let context = CGContext(
            data  : data,
            width : Int(frameSize.width),
            height: Int(frameSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space      : rgbColorSpace,
            bitmapInfo : bitmapInfo.rawValue
        )

        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}
