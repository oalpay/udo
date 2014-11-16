//
//  UDPopTipView.swift
//  udo
//
//  Created by Osman Alpay on 15/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class UDPopTipView: CMPopTipView {
    
    override init!(message messageToShow: String!) {
        super.init(message: messageToShow)
    }
    
    override init!(title titleToShow: String!, message messageToShow: String!) {
        super.init(title: titleToShow, message: messageToShow)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.dismissTapAnywhere = true
        self.has3DStyle = false
        self.backgroundColor = AppTheme.reminderCellNewColor
        self.hasGradientBackground = false
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
