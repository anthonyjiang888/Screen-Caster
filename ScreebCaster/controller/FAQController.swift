//
//  FAQController.swift
//  ui_demo
//
//  Created by umer on 12/10/2019.
//  Copyright © 2019 umer. All rights reserved.
//

import UIKit

class FAQController: UIViewController {

    // MARK: - IBOUTLETS
    @IBOutlet weak var faqTableView: UITableView!

    //MARK: - View LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Help"

//        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "policy"), style: .plain, target: self, action: #selector(openPolicyLink))
        
        let buttonWidth = CGFloat(30)
        let buttonHeight = CGFloat(30)

        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "policy"), for: .normal)
        button.addTarget(self, action: #selector(openPolicyLink), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true

        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(customView: button)

        // Do any additional setup after loading the view.
    }

    // MARK: - Selectors
    @objc func openPolicyLink() {
        guard let url = URL(string: "https://macosapp.weebly.com/privacy-policy.html") else { return }
        UIApplication.shared.open(url)
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
