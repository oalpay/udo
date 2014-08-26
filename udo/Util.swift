//
//  util.swift
//  udo
//
//  Created by Osman Alpay on 04/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation


struct UDOUtil {
    static func stripPhoneNumber(number:String) -> String {
        return join("",number.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet().invertedSet))
    }
}