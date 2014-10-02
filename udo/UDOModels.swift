//
//  UDOModels.swift
//  udo
//
//  Created by Osman Alpay on 21/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

let KReminderPushReceivedNotification = "KReminderPushReceivedNotification"
let KRemindersChangedNotification = "KRemindersChangedNotification"

let kReminderTitle = "title"
let kReminderAlarmDate = "alarmDate"
let kReminderCollaborators = "collaborators"
let kReminderDones = "dones"


let kUserCalendarId = "calendarId"

class Reminder : PFObject, PFSubclassing{
    @NSManaged var collaborators:[String]!
    @NSManaged var dones:[String]!
    @NSManaged var title:String!
    @NSManaged var dueDate:NSDate!
    
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
        for done in self.dones {
            if done == username {
                return true
            }
        }
        return false
    }
    
    func isCurrentUserAdmin() -> Bool {
        return self.collaborators.first? == PFUser.currentUser().username
    }
    
    override func isEqual(object: AnyObject?) -> Bool {
        let other = object as Reminder
        if self.title != other.title {
            return false
        }
        if self.dueDate.isEqualToDate(other.dueDate) {
            return false
        }
        if !NSSet(array: self.dones).isEqualToSet(NSSet(array: other.dones)) {
            return false
        }
        if !NSSet(array: self.dones).isEqualToSet(NSSet(array: other.dones)) {
            return false
        }
        return true
    }
    
    func doneRatio() -> Double {
        if self.dones == nil {
            return 0
        }
        return Double(self.dones.count) / Double(self.collaborators.count)
    }
}

class Reminders {
    class func updateReminderStatusInBackground(reminders:[Reminder]){
        var application = UIApplication.sharedApplication()
        var bgTask:UIBackgroundTaskIdentifier!
        bgTask = application.beginBackgroundTaskWithExpirationHandler { () -> Void in
            application.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            application.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        })
        
    }
}