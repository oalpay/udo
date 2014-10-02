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
    func itemAddedToEventStore(item:Reminder!, withEventStoreId id:String!)
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
    
    var userDefaults = NSUserDefaults.standardUserDefaults()
    
    private func getCalendarIdForReminder( reminder:Reminder! ) -> String? {
        let settings = userDefaults.dictionaryForKey("reminders") as? Dictionary<String,String>
        return settings?[reminder.objectId]
    }
    
    private func getEKReminderForReminder( reminder:Reminder! ) -> EKReminder? {
        if let id = self.getCalendarIdForReminder(reminder) {
            return self.eventStore.calendarItemWithIdentifier(id) as? EKReminder
        }
        return nil
    }
    
    private func saveCalendarId( calendarId:String, forReminder:Reminder!){
        var newSettings:Dictionary<String,String>!
        let settings = userDefaults.dictionaryForKey("reminders") as? Dictionary<String,String>
        if let s = settings {
            newSettings = s as Dictionary<String,String>
        } else {
            newSettings = Dictionary<String,String>()
        }
        newSettings[forReminder.objectId] = calendarId
        userDefaults.setObject(newSettings, forKey: "reminders")
        userDefaults.synchronize()
    }
    
    
    func requestAccess(callerCompletion: EKEventStoreRequestAccessCompletionHandler!) {
        self.eventStore.requestAccessToEntityType(EKEntityTypeReminder, completion: { (granted:Bool, error:NSError!) -> Void in
            self.accessGranted = granted
            callerCompletion(granted,error)
        })
        self.eventStore.refreshSourcesIfNecessary()
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
    
    private func getCalendar() -> EKCalendar? {
        var calendarOption:EKCalendar?
        let calendarIdOption = userDefaults.stringForKey("calendarId")
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
                self.userDefaults.setObject(calendarOption!.calendarIdentifier, forKey: "calendarId")
                self.userDefaults.synchronize()
            }
        }
        return calendarOption
    }
    
    private func createEKReminder() -> EKReminder {
        var reminder = EKReminder(eventStore: self.eventStore)
        reminder.calendar = getCalendar()
        return reminder
    }
    
    private func saveEKReminder(ekReminder:EKReminder!, commit:Bool) -> NSError? {
        var error:NSError?
        self.eventStore.saveReminder(ekReminder, commit: commit, error: &error)
        if error != nil{
            println("e:saveEKReminder:\(error)")
        }
        return error
    }
    
    private func deleteEKReminder(ekReminder:EKReminder!, commit:Bool) -> NSError? {
        var error:NSError?
        self.eventStore.removeReminder(ekReminder, commit: commit, error: &error)
        if error != nil{
            println("e:saveEKReminder:\(error)")
        }
        return error
    }
    
    
    func isReminderOnCalendar(reminder:Reminder) -> Bool {
        if reminder.objectId == nil {
            return false
        }
        var ekReminder = self.getEKReminderForReminder(reminder)
        if ekReminder != nil {
            return true
        }
        return false
    }
    
    private func setEKReminder(ekReminder:EKReminder!, withReminder:Reminder!, andAlarmDate:NSDate!){
        ekReminder.title = withReminder.title
        if andAlarmDate != nil {
            let alarm = EKAlarm(absoluteDate: andAlarmDate)
            ekReminder.alarms = [alarm]
        }else{
            ekReminder.alarms = []
        }
    }
    
    func mergeReminderToEventStore(reminder:Reminder!, alarmDate:NSDate!){
        var ekReminderOption = self.getEKReminderForReminder(reminder)
        if let ekReminder = ekReminderOption {
             self.setEKReminder(ekReminder, withReminder: reminder, andAlarmDate: alarmDate)
            self.saveEKReminder(ekReminder,commit: true)
        }else{
            var ekReminder = self.createEKReminder()
            self.setEKReminder(ekReminder, withReminder: reminder, andAlarmDate: alarmDate)
            self.saveEKReminder(ekReminder,commit: true)
            self.saveCalendarId(ekReminder.calendarItemIdentifier, forReminder: reminder)
        }
    }
    
    func removeReminderFromEventStore(reminder:Reminder){
        var ekReminder = self.getEKReminderForReminder(reminder)
        if ekReminder != nil {
            self.deleteEKReminder(ekReminder,commit:true)
        }
    }
    
    func getAlarmDateForReminder(reminder:Reminder) -> NSDate! {
        var ekReminder = self.getEKReminderForReminder(reminder)
        if let ekr = ekReminder {
            if ekr.alarms?.count > 0 {
                var alarm = ekr.alarms[0] as EKAlarm
                return alarm.absoluteDate
            }
        }
        return nil
    }
    
}
