//
//  UDBadgeLabel.swift
//  udo
//
//  Created by Osman Alpay on 10/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation


class UDBadgeLabel:UILabel {
    
    override func awakeFromNib() {
        self.backgroundColor = AppTheme.bagdeColor
        self.layer.cornerRadius = self.frame.size.height / 2
        self.layer.masksToBounds = true
    }
    
 
    override func layoutSubviews() {
        super.layoutSubviews()
        let sizeThatFits = self.sizeThatFits(self.frame.size)
        let incrementWidth = max(sizeThatFits.width + 5, 20) - self.frame.size.width
        self.frame.size.width += incrementWidth
        self.frame.origin.x -= incrementWidth
    }
}