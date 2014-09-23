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
    func itemAddedToEventStore(item:ReminderItem!, withEventStoreId id:String!)
    func itemRemovedFromEventStore(eventStoreId:String!)
}

class UDOReminderManager{
    class var sharedInstance : UDOReminderManager {
    struct Static {
        static let instance : UDOReminderManager = UDOReminderManager()
        }
        return Static.instance
    }
    
    var delegate:UDOReminderManagerDelegate?
    
    var eventStore = EKEventStore()
    
    var accessGranted = false
    
    
    func requestAccess(callerCompletion: EKEventStoreRequestAccessCompletionHandler!) {
        self.eventStore.requestAccessToEntityType(EKEntityTypeReminder, completion: { (granted:Bool, error:NSError!) -> Void in
            self.accessGranted = granted
            callerCompletion(granted,error)
        })
    }
    
    private func createCalendar() -> EKCalendar? {
        var calendar = EKCalendar(forEntityType: EKEntityTypeReminder, eventStore: self.eventStore)
        calendar.title = "u.do"
        var theSource:EKSource!
        for source in self.eventStore.sources() as [EKSource]{
            //first try icloud then local
            if (source.sourceType.value == EKSourceTypeCalDAV.value && source.title == "iCloud") || (source.sourceType.value == EKSourceTypeLocal.value && theSource == nil){
                theSource = source
            }
        }
        calendar.source = theSource
        var error:NSError?
        self.eventStore.saveCalendar(calendar, commit: true, error: &error)
        if error != nil{
            println("e:mergeReminders:\(error)")
            return nil
        }
        return calendar
    }
    
    func getCalendar() -> EKCalendar? {
        var calendarOption:EKCalendar?
        let calendarIdOption = PFUser.currentUser()[kUserCalendarId] as? String
        if let calendarId = calendarIdOption {
            calendarOption = self.eventStore.calendarWithIdentifier(calendarId)
            if calendarOption == nil {
                //calendar is deleted
            }
        }
        if calendarOption == nil {
            calendarOption = self.createCalendar()
        }
        if calendarOption != nil {
            if calendarIdOption == nil || calendarIdOption? != calendarOption?.calendarIdentifier{
                PFUser.currentUser()[kUserCalendarId] = calendarOption!.calendarIdentifier
                PFUser.currentUser().saveInBackground()
            }
        }
        return calendarOption
    }
    
    func addItemToReminders(item:NSMutableDictionary!){
        self.mergeItem(item, forceAdd: true, commit: true)
    }
    
    private func createItem() -> EKReminder {
        var reminder = EKReminder(eventStore: self.eventStore)
        reminder.calendar = getCalendar()
        return reminder
    }
    
    private func mergeItem(item:NSMutableDictionary!,forceAdd:Bool,commit:Bool) -> Bool{
        var isItemDirty = false
        var ekReminder:EKReminder?
        var itemIds = NSMutableDictionary(dictionary: item[kReminderItemCalendarIds] as NSDictionary)
        if let itemId = itemIds[PFUser.currentUser().username] as? String{
            if itemId != "0" {
                ekReminder = self.eventStore.calendarItemWithIdentifier(itemId) as? EKReminder
                if ekReminder == nil {
                    //item is deleted from reminders
                    itemIds[PFUser.currentUser().username] = "0"
                    isItemDirty = true
                }
            } else if forceAdd {
                ekReminder = self.createItem()
                itemIds[PFUser.currentUser().username] = ekReminder!.calendarItemIdentifier
                isItemDirty = true
            }
        }else{
            //new item
            ekReminder = self.createItem()
            itemIds[PFUser.currentUser().username] = ekReminder!.calendarItemIdentifier
            isItemDirty = true
        }
        if isItemDirty {
            item[kReminderItemCalendarIds] = itemIds
        }
        if let ekr = ekReminder {
            if ekr.title != item[kReminderItemDescription] as? String {
                ekr.title = item[kReminderItemDescription] as String
                var error:NSError?
                self.eventStore.saveReminder(ekr, commit: commit, error: &error)
                if error != nil{
                    println("e:mergeReminders:\(error)")
                }
            }
        }
        return isItemDirty
    }
    
    func mergeReminders(reminders:[ReminderCard] ){
        if !self.accessGranted {
            return
        }
        let calendar = self.getCalendar()
        if calendar == nil {
            println("e:mergeReminders:calendar is nil")
            return
        }
        
        for reminder in reminders as [PFObject]{
            var newItems:[NSMutableDictionary] = []
            var isItemDirty = false
            for newItem in reminder[kReminderCardItems] as [NSDictionary] {
                var item = NSMutableDictionary(dictionary: newItem)
                newItems.append(item)
                isItemDirty = self.mergeItem(item, forceAdd:false, commit:false)
            }
            if isItemDirty || reminder.isDirty() {
                reminder[kReminderCardItems] = newItems
                reminder.saveInBackgroundWithBlock({ (success:Bool, parseError:NSError!) -> Void in
                    var eventError:NSError?
                    if success {
                        self.eventStore.commit(&eventError)
                        if eventError != nil {
                            println("e:mergeReminders:\(eventError)")
                        }
                    }else{
                        println("e:mergeReminders:\(parseError)")
                    }
                })
            }else {
                var error:NSError?
                self.eventStore.commit(&error)
                if error != nil {
                    println("e:mergeReminders:\(error)")
                }
                
            }
        }
        
    }
    
}
