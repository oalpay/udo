//
//  Theme.swift
//  udo
//
//  Created by Osman Alpay on 15/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

func UIColorFromRGB(rgbValue: UInt) -> UIColor {
    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}

var LighColor = UIColorFromRGB(0xcfd8dc)
var DarkColor = UIColorFromRGB(0x607d8b)
var DarkColor2 = UIColorFromRGB(0x795548)
var InternationalOrange = UIColorFromRGB(0xFF4F00)
var GoldenGateColor = UIColorFromRGB(0xC0362C)
var DarkGoldenGateColor = UIColorFromRGB(0xAB1715)

class Theme {
    var tintColor = InternationalOrange
    var logoColor = DarkColor
    var doneColor = DarkColor
    var unDoneColor = UIColor.lightGrayColor()
    var doneRingBackgroudColor = UIColor.lightGrayColor()
    var doneRingForegroundColor = DarkColor
    var unRegisteredUserColor = DarkGoldenGateColor
    var iconMaskColor = DarkColor2
    var reminderTitleColor = UIColor.darkTextColor()
    var reminderHeaderColor = UIColor.darkGrayColor()
    var dateTimeColor = UIColor.darkGrayColor()
    var dateTimeWarningColor = GoldenGateColor
}

var AppTheme = Theme()