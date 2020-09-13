//
//  TableViewCell.swift
//  ui_demo
//
//  Created by TAQI RAZA on 12/10/2019.
//  Copyright © 2019 Ray. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {

    @IBOutlet var questionLabel: UILabel!
    @IBOutlet var answerLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
