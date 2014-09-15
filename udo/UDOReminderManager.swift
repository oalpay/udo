//
//  UDOReminderManager.swift
//  udo
//
//  Created by Osman Alpay on 15/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import EventKit

protocol UDOReminderManagerDelegate{
    
}


class UDOReminderManager{
    class var sharedInstance : UDOReminderManager {
    struct Static {
        static let instance : UDOReminderManager = UDOReminderManager()
        }
        return Static.instance
    }
    
    var eventStore = EKEventStore()
    
    
    func requestAccess(callerCompletion: EKEventStoreRequestAccessCompletionHandler!) {
        self.eventStore.requestAccessToEntityType(EKEntityTypeReminder, completion: { (granted:Bool, error:NSError!) -> Void in
            callerCompletion(granted,error)
        })
    }
    
    func mergeReminders(){
        var myReminders = PFQuery(className: kReminderCardClassName)
        myReminders.whereKey(kReminderCardClassName, equalTo: PFUser.currentUser().username)
        myReminders.findObjectsInBackgroundWithBlock { (reminders:[AnyObject]!, error:NSError!) -> Void in
            if error != nil {
                println("e:mergeReminders:\(error)")
                return
            }
            for reminder in reminders as [PFObject]{
                
            }
        }
        
    }
    
}
