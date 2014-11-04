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
//var DarkColor = UIColorFromRGB(0x8bc34a)
var GreenColor = UIColorFromRGB(0x689f38)
var YellorColor = UIColorFromRGB(0xcddc39)
var DarkColor2 = UIColorFromRGB(0x795548)
var InternationalOrange = UIColorFromRGB(0xFF4F00)
//var InternationalOrange = UIColorFromRGB(0xff5722)

var GoldenGateColor = UIColorFromRGB(0xC0362C)
var DarkGoldenGateColor = UIColorFromRGB(0xAB1715)

class Theme {
    var wtfColor = UIColor.blackColor()
    var tintColor = InternationalOrange
    var logoColor = UIColorFromRGB(0x607d8b)
    var notReceivedColor = UIColor.clearColor()
    var doneColor = GreenColor
    var receivedColor = YellorColor
    var doneRingBackgroudColor = LighColor
    var doneRingForegroundColor = GreenColor
    var unRegisteredUserColor = UIColorFromRGB(0xe51c23)
    var iconMaskColor = InternationalOrange
    var iconPassiveMaskColor = UIColor.darkGrayColor()
    var reminderTitleColor = UIColor.darkTextColor()
    var reminderHeaderColor = UIColor.darkGrayColor()
    var dateTimeColor = UIColor.darkGrayColor()
    var dateTimeWarningColor = UIColor.redColor()
    var reminderCellNormalColor = UIColor.whiteColor()
    var reminderCellUnSeenColor = YellorColor
    var reminderCellNewColor = GreenColor
    var reminderCellOverdueColor = InternationalOrange
}

var AppTheme = Theme()