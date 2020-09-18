//
//  MirroringViewController.swift
//  ui_demo
//
//  Created by umer on 12/10/2019.
//  Copyright © 2019 umer. All rights reserved.
//

import UIKit
import ReplayKit
import Photos
import AVFoundation
import VideoToolbox
import MobileCoreServices

class VideoMirrorVC: UIViewController,
    AVPlayerItemOutputPullDelegate,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    UIPopoverControllerDelegate,
    UIGestureRecognizerDelegate,
    UIDocumentMenuDelegate,
    UIDocumentPickerDelegate
{

    // MARK: - IbOutlates & Variables -
    @IBOutlet weak var bulletLabelsView: UIView!
    @IBOutlet weak var questionMarkButton: UIButton!
     
    @IBOutlet weak var lblUrl: UILabel! {
        didSet {
            sAddr = getIpAddress()
            var sLabel : String! = "http://"
            sLabel += sAddr
            sLabel += "/1/1.htm"
            lblUrl.text = sLabel
        }
    }
    
    private var sAddr: String! = ""
  
    //MARK: - View LifeCycle -
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpMainUIAndData()
           
      
        initData()
    }

    override func viewDidAppear(_ animated: Bool) {
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // hide nevigation bar
        navigationController?.setNavigationBarHidden(true, animated: animated)
 
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // display nevigation bar
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    //MARK:- Custom Methods -
    func setUpMainUIAndData() {
        bulletLabelsView.layer.cornerRadius = 20.0
        bulletLabelsView.layer.borderColor = UIColor.black.cgColor
        bulletLabelsView.layer.borderWidth = 1.0
        questionMarkButton.layer.cornerRadius = questionMarkButton.frame.height/2
        questionMarkButton.layer.borderColor = UIColor.black.cgColor
        questionMarkButton.layer.borderWidth = 1.0

        self.view.layoutIfNeeded()
       
    }

    var count : Int32 = 0
    let session: UnsafeMutablePointer<VTCompressionSession?> = UnsafeMutablePointer<VTCompressionSession?>.allocate(capacity: 1)
    var lastSampleTime : CMTime?
    var m_nMirrorWidth = 0
    var m_nMirrorHeight = 0


    @objc private dynamic var player: AVPlayer!
    private var _myVideoOutputQueue: DispatchQueue!
    private var _notificationToken: AnyObject?
    private var _timeObserver: AnyObject?

    private var videoOutput: AVPlayerItemVideoOutput!
    private var displayLink: CADisplayLink!

    private var popover: UIPopoverController?

    @IBOutlet weak var slideControl: UISlider!
    @IBOutlet weak var btnPlay: UIButton!
    @IBOutlet weak var txtFileLabel: UILabel!


    private let ONE_FRAME_DURATION = 0.03


    private var mProcessMode = 0
    private var m_nOpenMode = 0

    private var m_nVideoNum = 0
    private var m_nImageNum = 0
    private var m_nPDFNum = 0
    private var pdfDocument: CGPDFDocument?

    var videoList = [PHAsset]()
    var imageList = [PHAsset]()
    var pdfList = [URL]()

    func initData() {
         // init UI
        self.slideControl.value = 0

        player = AVPlayer()
        self.addTimeObserverToPlayer()

        // Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
        let pixBuffAttributes: [String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String :  Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) as AnyObject
        ]
        self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixBuffAttributes)
        _myVideoOutputQueue = DispatchQueue(label: "myVideoOutputQueue", attributes: [])
        self.videoOutput.setDelegate(self, queue: _myVideoOutputQueue)

        // Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
        self.displayLink = CADisplayLink(target: self, selector: #selector(MirroringViewController.displayLinkCallback(_:)))
        self.displayLink.add(to: RunLoop.current, forMode: .default)
        self.displayLink.isPaused = true

        mProcessMode = 0
        self.txtFileLabel.text = "0/0"
    }
    
    //### We need an explicit authorization to access properties of assets in Photos.
    private func requestPhotoPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            self.getImageAssetList()
            self.getVideoAssetList()
            return true
        case .denied:
            return false
        case .notDetermined, .restricted:
            PHPhotoLibrary.requestAuthorization {newStatus in
                self.getImageAssetList()
                self.getVideoAssetList()
                
                DispatchQueue.main.async(execute: {
                    if( self.m_nOpenMode == 1 )
                    {
                       self.openVideoPicker()
                    }
                    if( self.m_nOpenMode == 2 )
                    {
                       self.openImagePicker()
                    }
                  
                })
                
               
            }
        @unknown default:
            break
        }
        
        return false
    }

    private func addTimeObserverToPlayer() {
        /*
        Adds a time observer to the player to periodically refresh the time label to reflect current time.
        */
        if _timeObserver != nil {
            return
        }
        /*
        Use __weak reference to self to ensure that a strong reference cycle is not formed between the view controller, player and notification block.
        */
        _timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 10),
            queue: .main
        ) { [weak self] time in
            self?.syncTimeLabel()
        } as AnyObject?
    }

    private func removeTimeObserverFromPlayer() {
        if _timeObserver != nil {
            player.removeTimeObserver(_timeObserver!)
            _timeObserver = nil
        }
    }

    private func addDidPlayToEndTimeNotificationForPlayerItem(_ item: AVPlayerItem) {
        /*
        Setting actionAtItemEnd to None prevents the movie from getting paused at item end. A very simplistic, and not gapless, looped playback.
        */
        player.actionAtItemEnd = .none
        _notificationToken = NotificationCenter.default.addObserver(forName: Notification.Name.AVPlayerItemDidPlayToEndTime, object: item, queue: OperationQueue.main) {note in
            // Simple item playback rewind.
            self.player.currentItem?.seek(to: .zero)
        }
    }

    private func syncTimeLabel() {

        if let duration = player.currentItem?.duration {

            let durationSeconds = CMTimeGetSeconds(duration)
            var seconds = CMTimeGetSeconds(player.currentTime())
            if !seconds.isFinite {
                seconds = 0
            }

            var secondsInt = Int32(round(seconds))
            let minutes = secondsInt/60
            secondsInt -= minutes*60

            let progress = Float(seconds/durationSeconds)

            self.slideControl.value = progress
        }

    }

    //MARK: - CADisplayLink Callback

    @objc func displayLinkCallback(_ sender: CADisplayLink) {
        /*
        The callback gets called once every Vsync.
        Using the display link's timestamp and duration we can compute the next time the screen will be refreshed, and copy the pixel buffer for that time
        This pixel buffer can then be processed and later rendered on screen.
        */
        var outputItemTime = CMTime.invalid

        // Calculate the nextVsync time which is when the screen will be refreshed next.
        let nextVSync = (sender.timestamp + sender.duration)

        outputItemTime = self.videoOutput.itemTime(forHostTime: nextVSync)

        if self.videoOutput.hasNewPixelBuffer(forItemTime: outputItemTime) {
            var outputTime = CMTime.zero
            let pixelBuffer = self.videoOutput.copyPixelBuffer(forItemTime: outputItemTime, itemTimeForDisplay: &outputTime)

            let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName)
            userDefaults?.set("0", forKey: "orient")

            self.processBuffer(imageBuffer: pixelBuffer!)
        }
    }

    //MARK: - AVPlayerItemOutputPullDelegate

    func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        // Restart display link.
        self.displayLink.isPaused = false
    }

    //MARK: - Image Picker Controller Delegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if UIDevice.current.userInterfaceIdiom == .pad {
            self.popover?.dismiss(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }

        if let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String {
//            var url = info[.referenceURL] as! URL
            let asset = info[.phAsset] as! PHAsset
            let sel_fileid = asset.localIdentifier
            
            if (mediaType == "public.movie") {
                self.setupPlaybackForAsset(asset)

                mProcessMode = 1
                m_nVideoNum = 0
                
                for i in 0 ..< videoList.count {
                    let item = videoList[i]
                    let fileid = item.localIdentifier
                    if( sel_fileid == fileid)
                    {
                        m_nVideoNum = i
                    }
                }
                
                self.txtFileLabel.text = "\(m_nVideoNum + 1)/\(videoList.count)"
                
            }

            if (mediaType == "public.image") {
                sendImageAssetData(asset: asset)

                mProcessMode = 2
                m_nImageNum = 0
                
                for i in 0 ..< imageList.count {
                    let item = imageList[i]
                    let fileid = item.localIdentifier
                    if( sel_fileid == fileid)
                    {
                        m_nImageNum = i
                    }
                }
                
                setSlideControlValue(num: m_nImageNum, count: imageList.count)
                
                self.txtFileLabel.text = "\(m_nImageNum + 1)/\(imageList.count)"
            }
        }

        picker.delegate = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)

        if( mProcessMode == 1 ) {
            // Make sure our playback is resumed from any interruption.
            if let item = player.currentItem {
                self.addDidPlayToEndTimeNotificationForPlayerItem(item)
            }

            self.videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: ONE_FRAME_DURATION)

            btnPlay.setTitle("Pause", for: UIControl.State.normal)
            player.play()
        }

        picker.delegate = nil
    }

    //MARK: - Popover Controller Delegate

    func popoverControllerDidDismissPopover(_ popoverController: UIPopoverController) {
        // Make sure our playback is resumed from any interruption.
        if let item = player.currentItem {
            self.addDidPlayToEndTimeNotificationForPlayerItem(item)
        }
        self.videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: ONE_FRAME_DURATION)

        btnPlay.setTitle("Pause", for: UIControl.State.normal)
        player.play()

        self.popover?.delegate = nil
    }

    //MARK: - Playback setup
    
    private func setupPlaybackForAsset(_ asset: PHAsset) {
        asset.getURL { (url) in
            if( url == nil ) {
                return;
            }
            
            self.setupPlaybackForURL(url!)
        }
    }

    private func setupPlaybackForURL(_ URL: Foundation.URL) {
        /*
        Sets up player item and adds video output to it.
        The tracks property of an asset is loaded via asynchronous key value loading, to access the preferred transform of a video track used to orientate the video while rendering.
        After adding the video output, we request a notification of media change in order to restart the CADisplayLink.
        */

        // Remove video output from old item, if any.
        player.currentItem?.remove(self.videoOutput)

        let item = AVPlayerItem(url: URL)
        let asset = item.asset

        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {

            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "tracks", error: &error)
            if status == .loaded {
                let tracks = asset.tracks(withMediaType: .video)
                if !tracks.isEmpty {
                    // Choose the first video track.
                    let videoTrack = tracks[0]
                    videoTrack.loadValuesAsynchronously(forKeys: ["preferredTransform"]) {

                        if videoTrack.statusOfValue(forKey: "preferredTransform", error: nil) == .loaded {
                            let preferredTransform = videoTrack.preferredTransform

                            /*
                            The orientation of the camera while recording affects the orientation of the images received from an AVPlayerItemVideoOutput. Here we compute a rotation that is used to correctly orientate the video.
                            */
                             self.addDidPlayToEndTimeNotificationForPlayerItem(item)

                            DispatchQueue.main.async {
                                item.add(self.videoOutput)
                                self.player.replaceCurrentItem(with: item)
                                self.videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: self.ONE_FRAME_DURATION)

                                self.btnPlay.setTitle("Pause", for: UIControl.State.normal)
                                self.player.play()
                            }
                        }
                    }
                }
            } else {
                print(status, error)
            }
        }

    }
    
    func openVideoPicker()
    {
        player.pause()
        self.displayLink.isPaused = true

        if self.popover?.isPopoverVisible ?? false {
            self.popover?.dismiss(animated: true)
        }
        // Initialize UIImagePickerController to select a movie from the camera roll
        let videoPicker = APLImagePickerController()
        videoPicker.delegate = self
        videoPicker.modalPresentationStyle = .currentContext
        videoPicker.sourceType = .savedPhotosAlbum
        videoPicker.mediaTypes = [kUTTypeMovie as String]

//        if UIDevice.current.userInterfaceIdiom == .pad {
//            self.popover = UIPopoverController(contentViewController: videoPicker)
//            self.popover!.delegate = self
//            self.popover!.present(from: sender as! UIBarButtonItem, permittedArrowDirections: .down, animated: true)
//        } else {
            self.present(videoPicker, animated: true, completion: nil)
//        }
    }

    @IBAction func onLoadVideo(_ sender: Any) {
        if let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName) {
             let isIPAPurchased = userDefaults.bool(forKey: kIsIAPPurchased)
             if( !isIPAPurchased ) {
                 return;
             }
        }
        
        m_nOpenMode = 1
        if( self.requestPhotoPermission() == false )
        {
            return
        }
     
        openVideoPicker()
    }
    
    func openImagePicker()
    {
        player.pause()
        self.displayLink.isPaused = true

        if self.popover?.isPopoverVisible ?? false {
            self.popover?.dismiss(animated: true)
        }

        // Initialize UIImagePickerController to select a movie from the camera roll
        let videoPicker = APLImagePickerController()
        videoPicker.delegate = self
        videoPicker.modalPresentationStyle = .currentContext
        videoPicker.sourceType = .savedPhotosAlbum
        videoPicker.mediaTypes = ["public.image"]

//        if UIDevice.current.userInterfaceIdiom == .pad {
//            self.popover = UIPopoverController(contentViewController: videoPicker)
//            self.popover!.delegate = self
//            self.popover!.present(from: sender as! UIBarButtonItem, permittedArrowDirections: .down, animated: true)
//        } else {
            self.present(videoPicker, animated: true, completion: nil)
//        }
    }

    @IBAction func onLoadImage(_ sender: Any) {
        m_nOpenMode = 2
        if( self.requestPhotoPermission() == false )
        {
            return
        }
        
        openImagePicker()
    }

    @IBAction func onLoadPDF(_ sender: Any) {
      
        if let userDefaults = UserDefaults(suiteName: kUserDefaultsSuitName) {
             let isIPAPurchased = userDefaults.bool(forKey: kIsIAPPurchased)
             if( !isIPAPurchased ) {
                 return;
             }
        }
        
        player.pause()
        self.displayLink.isPaused = true

        if self.popover?.isPopoverVisible ?? false {
            self.popover?.dismiss(animated: true)
        }
        
        let importMenu = UIDocumentMenuViewController(documentTypes: [String(kUTTypePDF)], in: .import)
        importMenu.delegate = self
        importMenu.modalPresentationStyle = .currentContext
        present(importMenu, animated: true, completion: nil)
        
    }
    
    func loadPDFPage(page: Int)
    {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        
        let pdfPage = pdfDocument?.page(at: page + 1)!

        let mediaBoxRect = pdfPage?.getBoxRect(.mediaBox)
        let scale = CGFloat(200 / 72.0)
        let width = Int(mediaBoxRect!.width * scale)
        let height = Int(mediaBoxRect!.height * scale)

        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo)!
        context.interpolationQuality = .high
        
        let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.setFillColor(white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.drawPDFPage(pdfPage!)

        let image = context.makeImage()!
        
        let uiImage = UIImage(cgImage: image)
        let array = uiImage.jpegUInt8()
        
        sendDataToClient(array: array)
    }
    
    func setSlideControlValue(num: Int, count: Int)
    {
        if( count < 2 )
        {
            self.slideControl.value = 0
            return
        }
        
        let progress = Float(num)/Float(count - 1)
        self.slideControl.value = progress
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        /// Handle your document
        
        pdfDocument = CGPDFDocument(url as CFURL)!
        
        mProcessMode = 3
        m_nPDFNum = 0
        let totalPageCount = (pdfDocument?.numberOfPages)!
        self.txtFileLabel.text = "\(m_nPDFNum + 1)/\(totalPageCount)"
        
        setSlideControlValue(num: m_nPDFNum, count: totalPageCount)
        
        loadPDFPage(page: m_nPDFNum)
    }
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .overCurrentContext
        present(documentPicker, animated: true, completion: nil)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        /// Picker was cancelled! 
    }
    
    
    @IBAction func onClickPlayButton(_ sender: Any) {
        if (mProcessMode == 1) {
            if (player.timeControlStatus == AVPlayer.TimeControlStatus.playing) {
                btnPlay.setTitle("Play", for: UIControl.State.normal)
                player.pause()
                return;
            }

            if (player.timeControlStatus == AVPlayer.TimeControlStatus.paused) {
                btnPlay.setTitle("Pause", for: UIControl.State.normal)
                player.play()
                return;
            }
        }
    }

    @IBAction func onChangeSlideValue(_ sender: Any) {
        if( mProcessMode == 1 )
        {
            if let duration = player.currentItem?.duration {

                let durationSeconds = CMTimeGetSeconds(duration)
                var newTime = self.slideControl.value * Float(durationSeconds)
                if newTime <= 0 {
                    newTime = 0
                }

                player?.seek(to: CMTime(value: CMTimeValue(newTime * 1000), timescale: 1000))
            }
        }
        
        if( mProcessMode == 2 )
        {
            if( imageList.count < 1 )
            {
                return
            }
            
            m_nImageNum = Int(self.slideControl.value * Float(imageList.count - 1))
            self.txtFileLabel.text = "\(m_nImageNum + 1)/\(imageList.count)"
            if( m_nImageNum < 1 )
            {
                m_nImageNum = 0
            }
            
            if( m_nImageNum >= imageList.count - 1 )
            {
                m_nImageNum = imageList.count - 1
            }

            sendImageAssetData(asset: imageList[m_nImageNum])
        }
        
        if( mProcessMode == 3 )
        {
            // PDF Mode
            if( pdfDocument == nil )
            {
                return;
            }
            
            let totalPageCount = (pdfDocument?.numberOfPages)!
            if( totalPageCount < 1 )
            {
                return;
            }
             
            m_nPDFNum = Int(self.slideControl.value * Float(totalPageCount - 1))
            self.txtFileLabel.text = "\(m_nPDFNum + 1)/\(totalPageCount)"

            self.loadPDFPage(page: self.m_nPDFNum)
        }
    }

    @IBAction func onClickPrev(_ sender: Any) {
        if (mProcessMode == 1) {
            // Video Mode
            if (videoList.count < 1) {
                return;
            }

            m_nVideoNum = (m_nVideoNum - 1) % videoList.count
            self.txtFileLabel.text = "\(m_nVideoNum + 1)/\(videoList.count)"

            self.setupPlaybackForAsset(videoList[m_nVideoNum])
        }

        if (mProcessMode == 2) {
            // Image Mode
            if (imageList.count < 1) {
                return;
            }

            m_nImageNum = (m_nImageNum + imageList.count - 1) % imageList.count
            self.txtFileLabel.text = "\(m_nImageNum + 1)/\(imageList.count)"
            
            setSlideControlValue(num: m_nImageNum, count: imageList.count)

            sendImageAssetData(asset: imageList[m_nImageNum])
        }
        
        if(mProcessMode == 3 )
        {
            // PDF Mode
            if( pdfDocument == nil )
            {
                return;
            }
            
            let totalPageCount = (pdfDocument?.numberOfPages)!
            if( totalPageCount < 1 )
            {
                return;
            }
             
            m_nPDFNum = (m_nPDFNum + totalPageCount - 1) % totalPageCount
            self.txtFileLabel.text = "\(m_nPDFNum + 1)/\(totalPageCount)"
            
            setSlideControlValue(num: m_nPDFNum, count: totalPageCount)

            loadPDFPage(page: m_nPDFNum)
        }

    }

    @IBAction func onClickNext(_ sender: Any) {
        if (mProcessMode == 1) {
            // Video Mode
            if (videoList.count < 1) {
                return;
            }

            m_nVideoNum = (m_nVideoNum + 1) % videoList.count
            self.txtFileLabel.text = "\(m_nVideoNum + 1)/\(videoList.count)"

            self.setupPlaybackForAsset(videoList[m_nVideoNum])
        }

        if (mProcessMode == 2) {
            // Image Mode
            if (imageList.count < 1) {
                return;
            }

            m_nImageNum = (m_nImageNum + 1) % imageList.count
            self.txtFileLabel.text = "\(m_nImageNum + 1)/\(imageList.count)"
            
            setSlideControlValue(num: m_nImageNum, count: imageList.count)

            sendImageAssetData(asset: imageList[m_nImageNum])
        }
        
        if(mProcessMode == 3 )
        {
            // PDF Mode
            if( pdfDocument == nil )
            {
                return;
            }
            
            let totalPageCount = (pdfDocument?.numberOfPages)!
            if( totalPageCount < 1 )
            {
                return;
            }
             
            m_nPDFNum = (m_nPDFNum + 1) % totalPageCount
            self.txtFileLabel.text = "\(m_nPDFNum + 1)/\(totalPageCount)"

            setSlideControlValue(num: m_nPDFNum, count: totalPageCount)
            
            loadPDFPage(page: m_nPDFNum)
        }
    }


    func initCodec(imageBuffer: CVImageBuffer) {
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        if (width == m_nMirrorWidth && height == m_nMirrorHeight) {
            return
        }

        m_nMirrorWidth = width
        m_nMirrorHeight = height

        print("Codec Init Start")
        VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_JPEG,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: session
        )

        print("Codec Init End")
    }

    func sendImageData(url : URL) {
        let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil)

        if let photo = fetchResult.firstObject {
            sendImageAssetData(asset: photo)
        }
    }
    
    func sendImageAssetData(asset : PHAsset) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
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

            let data: Data = (image?.jpegData(compressionQuality: 0.7)!)!
            var array = [UInt8]()
            array.append(contentsOf: data)

            sendDataToClient(array: array)
        }
       
    }

    func sendFileImageData(url : URL) {
        if let imageData = NSData(contentsOf: url) {
            let image = UIImage(data: imageData as Data) // Here you can attach image to UIImageView

            let data: Data = (image?.jpegData(compressionQuality: 0.7)!)!
            var array = [UInt8]()
            array.append(contentsOf: data)

            sendDataToClient(array: array)
        }
    }

    func processBuffer(imageBuffer: CVImageBuffer) {
        initCodec(imageBuffer:imageBuffer)

        let status = VTCompressionSessionEncodeFrame(
            session.pointee!,
            imageBuffer: imageBuffer,
            presentationTimeStamp: CMTime.invalid,
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
            if CMBlockBufferGetDataPointer(
                dataBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            ) == noErr {
                var intArray = Array(UnsafeBufferPointer(start: dataPointer, count: totalLength))
                sendDataToClient(array: intArray)
            }
        }
        
        if status != noErr {
            m_nMirrorWidth = 0
            m_nMirrorHeight = 0
        }
    }

    func getImageAssetList() {
        self.imageList.removeAll()
        
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d ", PHAssetMediaType.image.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: options)

        for i in 0 ..< fetchResult.count {
            let asset = fetchResult[i]
            self.imageList.append(asset)
        }

    }

    func getVideoAssetList() {
        self.videoList.removeAll()
        
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d ", PHAssetMediaType.video.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: .video, options: options)

        for i in 0 ..< fetchResult.count {
            let asset = fetchResult[i]
            
            self.videoList.append(asset)
        }

    }
    
    @IBAction func onBackPage(_ sender: Any) {
        player.pause()
        self.displayLink.isPaused = true
        
         self.navigationController?.popViewController(animated: true)
    }

}
