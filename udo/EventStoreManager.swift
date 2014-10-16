//
//  EventStoreManager.swift
//  udo
//
//  Created by Osman Alpay on 15/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import EventKit





protocol EventStoreManagerDelegate{
    func itemChangedInStore(key:String!)
}

class EventStoreManager : NSObject{
    class var sharedInstance : EventStoreManager {
    struct Static {
        static let instance : EventStoreManager = EventStoreManager()
        }
        return Static.instance
    }
    
    var delegate:EventStoreManagerDelegate?
    
    var eventStore = EKEventStore()
    
    var accessGranted = false
    
    var userDefaults = NSUserDefaults.standardUserDefaults()
    
    var reminderManager = ReminderManager.sharedInstance
    
    var ekReminderCache = Dictionary<String,EKReminder>()
    
    var storeIds:Dictionary<String,String>!
    
    override init(){
        super.init()
        if let storeIds = userDefaults.dictionaryForKey("reminders") as? Dictionary<String,String>{
            self.storeIds = storeIds
        }else{
            self.storeIds = Dictionary<String,String>()
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "remindersChangedNotification:", name: kRemindersChangedNotification, object: nil)
    }
    
    func reset(){
        self.ekReminderCache.removeAll(keepCapacity: true)
        self.eventStore.reset()
    }

    func remindersChangedNotification(notification:NSNotification) {
        var changed = notification.object as RemindersChanged!
        var upserts = NSMutableArray()
        upserts.addObjectsFromArray(changed.inserts)
        upserts.addObjectsFromArray(changed.updates)
        for key in upserts {
            var sKey = key as String
            if self.isStored(sKey) {
                var reminder = self.reminderManager.getReminder(sKey)
                self.updateTitle(reminder.title , forKey: sKey)
            }
        }
        for key in changed.deletes {
            if self.isStored(key) {
                self.remove(key)
            }
        }
    }
    
    private func getStoreIdForKey( key:String! ) -> String? {
        return storeIds[key]
    }
    
    private func deleteStoreIdForKey( key:String! ){
        storeIds.removeValueForKey(key)
        userDefaults.setObject(storeIds, forKey: "reminders")
        userDefaults.synchronize()
    }
    
    private func getEKReminderForKey( key:String! ) -> EKReminder? {
        if let id = self.getStoreIdForKey(key) {
            if let cachedEkReminder = self.ekReminderCache[key] {
                return cachedEkReminder
            }
            if let ekReminder =  self.eventStore.calendarItemWithIdentifier(id) as? EKReminder {
                self.ekReminderCache[key] = ekReminder
                return ekReminder
            }else{
                self.deleteStoreIdForKey(key)
            }
        }
        return nil
    }
    
    private func saveStoreId( calendarId:String, forKey:String!){
        var newSettings:Dictionary<String,String>!
        let settings = userDefaults.dictionaryForKey("reminders") as? Dictionary<String,String>
        if let s = settings {
            newSettings = s as Dictionary<String,String>
        } else {
            newSettings = Dictionary<String,String>()
        }
        newSettings[forKey] = calendarId
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
    
    
    func isStored(key:String) -> Bool {
        var ekReminder = self.getEKReminderForKey(key)
        if ekReminder != nil {
            return true
        }
        return false
    }
    
    private func setEKReminder(ekReminder:EKReminder!, withTitle:String!, andAlarmDate:NSDate!) -> Bool{
        var isChanged = false
        if ekReminder.title != withTitle{
            ekReminder.title = withTitle
            isChanged = true
        }
        if andAlarmDate != nil {
            var oldAlarm:EKAlarm!
            if ekReminder.alarms?.count > 0 {
                oldAlarm = ekReminder.alarms[0] as EKAlarm
            }
            var newAlarm = EKAlarm(absoluteDate: andAlarmDate)
            if oldAlarm == nil || !oldAlarm.absoluteDate.isEqualToDate(newAlarm.absoluteDate){
                if oldAlarm != nil {
                    ekReminder.removeAlarm(oldAlarm)
                }
                ekReminder.addAlarm(newAlarm)
                isChanged = true
            }
        }else{
            if let alarms = ekReminder.alarms {
                for alarm in alarms as [EKAlarm] {
                    ekReminder.removeAlarm(alarm)
                    isChanged = true
                }
            }
        }
        return isChanged
    }
    
    func updateTitle(title:String!, forKey:String){
        if let ekReminder = self.getEKReminderForKey(forKey){
            if ekReminder.title != title {
                ekReminder.title = title
                self.saveEKReminder(ekReminder,commit: true)
            }
        }
    }
    
    func upsertWithTitle(title:String!, andAlarmDate:NSDate!, forKey:String!){
        if let ekReminder = self.getEKReminderForKey(forKey) {
            if self.setEKReminder(ekReminder, withTitle: title, andAlarmDate: andAlarmDate){
                self.saveEKReminder(ekReminder,commit: true)
                self.delegate?.itemChangedInStore(forKey)
            }
        }else{
            var ekReminder = self.createEKReminder()
            self.setEKReminder(ekReminder, withTitle: title, andAlarmDate: andAlarmDate)
            self.saveEKReminder(ekReminder,commit: true)
            self.saveStoreId(ekReminder.calendarItemIdentifier, forKey: forKey)
            self.delegate?.itemChangedInStore(forKey)
        }
    }
    
    func remove(key:String){
        if let ekReminder = self.getEKReminderForKey(key){
            self.ekReminderCache.removeValueForKey(key)
            self.deleteEKReminder(ekReminder,commit:true)
            self.deleteStoreIdForKey(key)
            self.delegate?.itemChangedInStore(key)
        }
    }
    
    func getAlarmDateForKey(key:String) -> NSDate! {
        if let ekr = self.getEKReminderForKey(key) {
            if ekr.alarms?.count > 0 {
                var alarm = ekr.alarms[0] as EKAlarm
                return alarm.absoluteDate
            }
        }
        return nil
    }
    
}
