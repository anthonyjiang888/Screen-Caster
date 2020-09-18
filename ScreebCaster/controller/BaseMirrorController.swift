//
//  BaseMirrorController.swift
//  ScreenBroadcaster
//
//  Created by Admin on 5/5/20.
//

import UIKit

class BaseMirrorController: UIViewController,
    UINavigationControllerDelegate {
     
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
         navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // display nevigation bar
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    @IBAction func onBackPage(_ sender: Any) {
         self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func onShareUrl(_ sender: Any) {
        var sUrl : String! = "http://"
        sUrl += getIpAddress()
        sUrl += kRootPath
        //let sAddrToShare = [sUrl]
        let sAddrToShare = [NSURL(string: sUrl)]
        let activityViewController = UIActivityViewController(
            activityItems: sAddrToShare as [Any],
            applicationActivities: nil
        )
        
        //avoiding to crash on iPad
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popoverController.sourceView = self.view
            popoverController.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
        }

        self.present(activityViewController, animated: true, completion: nil)
    }
}

