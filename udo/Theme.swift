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
var IndigoColor = UIColorFromRGB(0x3F51B5)
var BlueColor = UIColorFromRGB(0x2196F3)
var YellorColor = UIColorFromRGB(0xcddc39)
var AmberColor = UIColorFromRGB(0xFFC107)
var DarkColor2 = UIColorFromRGB(0x795548)
var InternationalOrange = UIColorFromRGB(0xFF4F00)
//var InternationalOrange = UIColorFromRGB(0xff5722)

var GoldenGateColor = UIColorFromRGB(0xC0362C)
var DarkGoldenGateColor = UIColorFromRGB(0xAB1715)

var LogoColor = UIColorFromRGB(0x607d8b)

class Theme {
    var wtfColor = UIColor.blackColor()
    var tintColor = InternationalOrange
    var logoColor = LogoColor
    var bagdeColor = BlueColor
    var notReceivedColor = UIColor.clearColor()
    var doneColor = GreenColor
    var receivedColor = AmberColor
    var doneRingBackgroudColor = LighColor
    var doneRingForegroundColor = GreenColor
    var unRegisteredUserColor = UIColorFromRGB(0xe51c23)
    var iconMaskColor = InternationalOrange
    var iconPassiveMaskColor = UIColor.darkGrayColor()
    var reminderTitleColor = UIColor.darkTextColor()
    var reminderHeaderColor = UIColor.darkGrayColor()
    var dateTimeColor = UIColor.darkGrayColor()
    var dateTimeWarningColor = InternationalOrange
    var reminderCellNormalColor = UIColor.whiteColor()
    var reminderCellUnSeenColor = AmberColor
    var reminderCellNewColor = BlueColor
    var reminderCellOverdueColor = InternationalOrange
}

var AppTheme = Theme()