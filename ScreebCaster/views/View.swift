//
//  View.swift
//  Raymond_IAP
//
//  Created by vedran on 25/11/2019.
//  Copyright © 2019 vedran. All rights reserved.
//

import UIKit

class View: UIView {

    @IBInspectable var cornerRadius: CGFloat = -1

    @IBInspectable var borderColor: UIColor?
    @IBInspectable var borderWidth: CGFloat = -1

    override func layoutSubviews() {
        self.apply()

        super.layoutSubviews()
        self.apply()
    }

    override func prepareForInterfaceBuilder() {
        self.apply()
    }

}


extension View {

    func apply() {

        if cornerRadius != -1 {
            layer.cornerRadius = cornerRadius
        }
        if borderColor != nil {
            layer.borderColor = borderColor?.cgColor
        }
        if borderWidth != -1 {
            layer.borderWidth = borderWidth
        }

    }
}

