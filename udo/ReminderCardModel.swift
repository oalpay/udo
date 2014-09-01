//
//  ReminderCardModel.swift
//  udo
//
//  Created by Osman Alpay on 13/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation


enum ReminderTaskStatus: Int {
    case New = 1, Done, Deleted
}

let kReminderItemStatus = "status"
let kReminderItemDescription = "description"
let kReminderItemAlarmDate = "alarmDate"
let kReminderCardOwner = "owner"
let kReminderCardCreator = "creator"
let kReminderCardItems = "items"

