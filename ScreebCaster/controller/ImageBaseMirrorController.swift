//
//  BaseMirrorController.swift
//  ScreenBroadcaster
//
//  Created by Admin on 5/5/20.
//

import UIKit
import Photos

class ImageBaseMirrorController: BaseMirrorController,
    UIImagePickerControllerDelegate,
    UIPopoverControllerDelegate     {
 
    @IBOutlet weak var containerMessage: UIView!
    @IBOutlet weak var txtMessage: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        containerMessage.layer.cornerRadius = 3
        containerMessage.layer.masksToBounds = true
    }
     
    @IBAction func onSendMessage(_ sender: Any) {
        let message = txtMessage.text
        if message != nil && message != "" {
            sendMessageToClient(text: message!)
            txtMessage.text = ""
        }
    }
    
    @IBAction func onClickImage(_ sender: Any) {
         if( self.requestPhotoPermission() == false )
         {
             return
         }
         
         openImagePicker()
    }
    
    private var popover: UIPopoverController?
    
    private func requestPhotoPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined, .restricted:
            PHPhotoLibrary.requestAuthorization {newStatus in
                
                DispatchQueue.main.async(execute: {
                   self.openImagePicker()
                })
                
               
            }
        @unknown default:
            break
        }
        
        return false
    }
    
    func openImagePicker()
    {
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if UIDevice.current.userInterfaceIdiom == .pad {
            self.popover?.dismiss(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }

        if let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String {
            let asset = info[.phAsset] as! PHAsset
            
            if (mediaType == "public.image") {
                sendImageAssetData(asset: asset)
            }
        }

        picker.delegate = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)

        picker.delegate = nil
    }


    func popoverControllerDidDismissPopover(_ popoverController: UIPopoverController) {
        self.popover?.delegate = nil
    }
}
