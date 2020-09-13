//
//  HighlightingButton.swift
//  Raymond_IAP
//
//  Created by vedran on 25/11/2019.
//  Copyright © 2019 vedran. All rights reserved.
//

import UIKit

class HighlightingButton: Button {

    let animationDuration = 0.3

    var highlighted_internal: Bool

    override init(frame: CGRect) {

        highlighted_internal = false

        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {

        highlighted_internal = false

        super.init(coder: aDecoder)
    }

    override var isHighlighted: Bool {

        set {

            if highlighted_internal != newValue {

                UIView.animate(withDuration: animationDuration) {
                    if newValue {
                        self.alpha = 0.5
                    } else {
                        self.alpha = 1
                    }
                }
            }

            highlighted_internal = newValue
        }

        get {
            return highlighted_internal
        }
    }

}

class Button: UIButton {

    @IBInspectable var cornerRadius: CGFloat = -1

    @IBInspectable var borderColor: UIColor?
    @IBInspectable var borderWidth: CGFloat = -1

    let templateText = "<<VALUE>>"
    var originalText: String?

    override init(frame: CGRect) {
        super.init(frame: frame)

        originalText = self.title(for: .normal)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        originalText = self.title(for: .normal)
    }

    override func layoutSubviews() {
        self.apply()

        super.layoutSubviews()
        self.apply()
    }

    override func prepareForInterfaceBuilder() {
        self.apply()
    }

}

extension Button {

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

