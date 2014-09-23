//
//  UDOModels.swift
//  udo
//
//  Created by Osman Alpay on 21/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation


enum ReminderTaskStatus: Int {
    case New = 1, Done, Deleted
}

let kReminderItemCalendarIds = "itemId"
let kReminderItemStatus = "status"
let kReminderItemDescription = "description"
let kReminderItemAlarmDate = "alarmDate"

let kReminderCardItems = "items"
let kReminderCardCollaborators = "collaborators"
let kReminderCardClassName = "ReminderCard"

let kUserCalendarId = "calendarId"

class ReminderItem : PFObject, PFSubclassing {
    @NSManaged var title:String!
    @NSManaged var alarmDate:NSDate!
    
    override class func load() {
        self.registerSubclass()
    }
    class func parseClassName() -> String! {
        return "ReminderItem"
    }
}

class ReminderCard : PFObject, PFSubclassing {
    @NSManaged var owners:[String]!
    @NSManaged var items:[ReminderItem]!
    
    override class func load() {
        self.registerSubclass()
    }
    class func parseClassName() -> String! {
        return kReminderCardClassName
    }
}


let kUserReminders = "UserReminders"
let kUserReminderCards = "UserReminder"
class UserReminders : PFObject, PFSubclassing,UDOReminderManagerDelegate {
    @NSManaged var cards: [ReminderCard]!
    @NSManaged var metaItems: Dictionary<String,String>!
    
    var reminderManager:UDOReminderManager!
    
   override  init() {
        super.init()
        self.reminderManager = UDOReminderManager.sharedInstance
        self.reminderManager.delegate = self
    }
    
    override class func load() {
        self.registerSubclass()
    }
    
    class func parseClassName() -> String! {
        return kUserReminders
    }
    
    func addCard(card:ReminderCard!){
        self.addObject(card, forKey: kUserReminderCards)
    }
    
    func addItem(item:ReminderItem!, toCard card:ReminderCard!, addToEventStore:Bool){
        card.addObject(item, forKey: kReminderCardItems)
    }
    
    func itemAddedToEventStore(item:ReminderItem!, withEventStoreId id:String!){
        self.metaItems[item.objectId] = id
    }
    
    func itemRemovedFromEventStore(eventStoreId:String!){
        for itemId in self.metaItems.keys{
            if self.metaItems[itemId] == eventStoreId {
                self.metaItems[itemId] = "0"
            }
        }
    }

}


func GetOtherUsernameFor(#reminder:ReminderCard) -> String? {
    let owners = reminder.owners
    for owner in owners {
        if owner != PFUser.currentUser().username {
            return owner
        }
    }
    return nil
}
