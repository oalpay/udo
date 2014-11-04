//
//  UDOModels.swift
//  udo
//
//  Created by Osman Alpay on 21/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

let kReminderTitle = "title"
let kReminderAlarmDate = "alarmDate"
let kReminderCollaborators = "collaborators"
let kReminderDones = "dones"


let kUserCalendarId = "calendarId"

var UserPublicQueryCache = NSCache()

class UserPublic : PFObject, PFSubclassing{
    @NSManaged var username:String!
    @NSManaged var name:String!
    @NSManaged var image:PFFile!
    
    override class func load() {
        self.registerSubclass()
    }
    class func parseClassName() -> String! {
        return "UserPublic"
    }
}

class Reminder : PFObject, PFSubclassing{
    @NSManaged var collaborators:[String]!
    @NSManaged var dones:[String]!
    @NSManaged var title:String!
    @NSManaged var dueDate:NSDate!
    @NSManaged var dueDateInterval:NSNumber!
    @NSManaged var received:[String]!
    
    
    var alarmDate:NSDate!
    var isOnReminders = false
    
    var failedToSave = false
    
    override class func load() {
        self.registerSubclass()
    }
    class func parseClassName() -> String! {
        return "Reminder"
    }
    
    func getOthers() -> [String] {
        return self.collaborators.filter({ (collaborator) -> Bool in
            return collaborator != PFUser.currentUser().username
        })
    }
    
    func setUserDone(){
        self.addUniqueObject(PFUser.currentUser().username, forKey: kReminderDones)
    }
    
    func setUserUnDone(){
        self.removeObject(PFUser.currentUser().username, forKey: kReminderDones)
    }
    
    func isCurrentUserDone() -> Bool {
        return self.isUserDoneOnModel(PFUser.currentUser().username)
    }
    
    func isUserDone(username:String) -> Bool {
        return self.isUserDoneOnModel(username)
    }
    
    private func isUserDoneOnModel(username:String) -> Bool {
        if self.dones == nil {
            return false
        }
        if (self.dones as NSArray).indexOfObject(username) != NSNotFound {
            return true
        }else {
            return false
        }
    }
    
    func isCurrentUserAdmin() -> Bool {
        return self.collaborators.first? == PFUser.currentUser().username
    }
    
    func completed() -> Bool {
        return self.doneRatio() == 1
    }
    
    func doneRatio() -> Double {
        if self.dones == nil || self.collaborators == nil{
            return 0
        }
        return Double(self.dones.count) / Double(self.collaborators.count)
    }
    
    func key() -> String {
        if self.objectId == nil {
            return String(self.hash)
        }else{
            return self.objectId
        }
    }
    
    func isOverDue(#passIfDone:Bool) -> Bool{
        if let dueDate = self.dueDate {
            if passIfDone && self.isCurrentUserDone() {
                return false
            }
            if dueDate.earlierDate(NSDate()) == dueDate {
                return true
            }
        }
        return false
    }
    
    // 0 none
    // 1 reveived
    // 2 done
    func stateForUser(username:String) -> Int{
        if self.dones != nil {
            if (self.dones as NSArray).containsObject(username) {
                return 2
            }
        }
        if self.received != nil {
            if (self.received as NSArray).containsObject(username) {
                return 1
            }
        }
        if username == PFUser.currentUser().username {
            return 1
        }else {
            return 0
        }
    }
    
}

enum DeliveryStatus: Int{
    case Sending = 0
    case Sent = 1
    case Error = 2
}

class ReminderNote : PFObject, PFSubclassing, JSQMessageData{
    @NSManaged var reminderId:String!
    @NSManaged var sender:String!
    @NSManaged var text:String!
    
    var deliveryStatus:DeliveryStatus!
    
    var contactsManager = ContactsManager.sharedInstance
    
    var sentAt:NSDate!
    
    override class func load() {
        self.registerSubclass()
    }
    class func parseClassName() -> String! {
        return "Note"
    }
    
    func senderId() -> String! {
        return sender
    }
    
    func senderDisplayName() -> String! {
       return self.contactsManager.getUDContactForUserId(sender).name()
    }
    
    func date() -> NSDate {
        if self.createdAt != nil {
            return self.createdAt
        }else {
            return NSDate()
        }
    }
    func isMediaMessage() -> Bool {
        return false
    }
    
    func createdAt() -> NSDate!{
        if super.createdAt != nil {
            return super.createdAt
        }
        return self.sentAt
    }

}