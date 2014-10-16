//
//  ReminderManager.swift
//  udo
//
//  Created by Osman Alpay on 12/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

var kRemindersChangedNotification = "kRemindersChangedNotification"
var kReminderLoadingNotification = "kReminderLoadingNotification"
var kReminderLoadingFinishedNotification = "kReminderLoadingFinishedNotification"

class RemindersChanged {
    let updates:[String]!
    let inserts:[String]!
    let deletes:[String]!
    
    init(updates:[String]!,inserts:[String]!,deletes:[String]!){
        self.updates = updates
        self.inserts = inserts
        self.deletes = deletes
        
        if self.updates == nil {
            self.updates = []
        }
        if self.inserts == nil {
            self.inserts = []
        }
        if self.deletes == nil {
            self.deletes = []
        }
    }
}

class ReminderManager{
    
    private var reminderMap = Dictionary<String,Reminder>()
    private var lastUpdated = NSDate(timeIntervalSince1970: 0)
    private var remoteNotificationSet = NSMutableSet()
    private var loadSet = NSMutableSet()
    private var loadErrorSet = NSMutableSet()
    
    private var nc = NSNotificationCenter.defaultCenter()
    
    private var localNotificationManager = LocalNotificationsManager()
    
    class var sharedInstance : ReminderManager {
    struct Static {
        static let instance : ReminderManager = ReminderManager()
        }
        return Static.instance
    }
    
    
    init() {

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "userLoggedIn:", name: kUserLoggedInNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "userLoggedOut:", name: kUserLoggedOutNotification, object: nil)
    }
    
    @objc func applicationDidFinishLaunchingNotification() {
        if PFUser.currentUser() != nil {
            self.fetchNewData(kPFCachePolicyCacheThenNetwork, resultBlock: { (_, _) -> Void in
            })
        }
    }
    
    @objc func applicationWillEnterForegroundNotification() {
        if PFUser.currentUser() != nil {
            self.fetchNewData(kPFCachePolicyNetworkOnly, resultBlock: { (_, _) -> Void in
                
            })
        }
    }
    
    private func notifyLoadForRemoteNotifications(){
        for key in self.remoteNotificationSet {
            self.remoteNotificationSet.removeObject(key)
            self.nc.postNotificationName(kReminderLoadingFinishedNotification, object: key)
        }
    }
    
    func userLoggedIn(notification:NSNotification){
        self.fetchNewData(kPFCachePolicyNetworkOnly, resultBlock: nil)
    }
    
    func userLoggedOut(notification:NSNotification){
        PFQuery.clearAllCachedResults()
        self.reminderMap.removeAll(keepCapacity: true)
        self.loadErrorSet.removeAllObjects()
        self.loadSet.removeAllObjects()
        self.remoteNotificationSet.removeAllObjects()
        self.lastUpdated = NSDate(timeIntervalSince1970: 0)
    }
    
    private func mergeReminders(newReminders:[Reminder]){
        var updates = [String]()
        var inserts = [String]()
        for newReminder in newReminders {
            if let reminder = self.reminderMap[newReminder.key()]{
                if reminder.updatedAt != nil && reminder.updatedAt.laterDate(newReminder.updatedAt) == newReminder.updatedAt {
                    updates.append(newReminder.key())
                }
            } else {
                inserts.append(newReminder.key())
            }
            self.reminderMap[newReminder.key()] = newReminder
        }
        if updates.count > 0 || inserts.count > 0 {
            var change = RemindersChanged(updates: updates, inserts: inserts, deletes: nil)
            self.nc.postNotificationName(kRemindersChangedNotification, object: change)
        }
    }
    
    
    private func fetchNewData(cachePolicy:PFCachePolicy, resultBlock:PFArrayResultBlock?){
        let remindersQuery = Reminder.query()
        remindersQuery.whereKey(kReminderCollaborators,equalTo:PFUser.currentUser().username)
        remindersQuery.whereKey("updatedAt", greaterThan: self.lastUpdated)
        remindersQuery.orderByAscending("updatedAt")
        remindersQuery.cachePolicy = cachePolicy
        remindersQuery.findObjectsInBackgroundWithBlock({
            (resultData:[AnyObject]!, error: NSError!) -> Void in
            if error == nil{
                var reminders = resultData as [Reminder]
                for reminder in reminders {
                    if self.lastUpdated.compare(reminder.updatedAt) == NSComparisonResult.OrderedAscending {
                        self.lastUpdated = reminder.updatedAt
                    }
                    self.localNotificationManager.updateForkey(reminder.key(), alertBodyOption: reminder.title, fireDateOption: reminder.dueDate)
                }
                self.mergeReminders(reminders)
            }else{
                //handle error
                println("e:fetchNewData: \(error)")
            }
            // remove all remote notifications it might be deleted from server
            self.notifyLoadForRemoteNotifications()
            resultBlock?(resultData,error)
        })
    }

    func remoteReminderChangeNotificationReceived(reminderId:String!,title:String?,dueDateOption:NSDate?){
        self.remoteNotificationSet.addObject(reminderId)
        var reminder = self.getReminder(reminderId)
        if reminder == nil {
            reminder = Reminder()
            reminder.objectId = reminderId
            reminder.title = title
            reminder.dueDate = dueDateOption
            reminder.collaborators = []
            self.reminderMap[reminderId] = reminder
            var change = RemindersChanged(updates: nil, inserts: [reminder.key()], deletes: nil)
            self.nc.postNotificationName(kRemindersChangedNotification, object: change)
        }
        self.localNotificationManager.updateForkey(reminderId, alertBodyOption: "\(title!) due time!", fireDateOption: dueDateOption)
        nc.postNotificationName(kReminderLoadingNotification, object: reminderId)
    }
    
    func remoteNotificationReceived(applicationState:UIApplicationState, userInfo:NSDictionary!, completionHandler:(UIBackgroundFetchResult) -> Void ){
        if let reminderId = userInfo["r"] as? String {
            var dueDate:NSDate?
            if let dueDateString = userInfo["d"] as? String {
                dueDate = NSDate(fromISO8601String: dueDateString)
            }
            var title = userInfo["t"] as? String
            self.remoteReminderChangeNotificationReceived(reminderId, title: title, dueDateOption: dueDate)
        }
        if applicationState == UIApplicationState.Active {
            self.refresh({ (resultData:[AnyObject]!, error:NSError!) -> Void in
                if error != nil {
                    completionHandler(UIBackgroundFetchResult.Failed)
                }else if resultData.count > 0 {
                    completionHandler(UIBackgroundFetchResult.NewData)
                }else{
                    completionHandler(UIBackgroundFetchResult.NoData)
                }
            })
        }else{
            completionHandler(UIBackgroundFetchResult.NoData)
        }
    }
    
    func refresh(resultBlock:PFArrayResultBlock?){
        self.fetchNewData(kPFCachePolicyNetworkOnly, resultBlock: resultBlock)
    }
    
    func getReminderKeys() -> [String]! {
        return self.reminderMap.keys.array
    }
    
    func getReminder(key:String) -> Reminder! {
        return self.reminderMap[key]
    }
    
    func deleteReminder(key:String) {
        var reminder = self.getReminder(key)
        if reminder.objectId != nil {
            reminder.removeObject(PFUser.currentUser().username, forKey: kReminderCollaborators)
            reminder.removeObject(PFUser.currentUser().username, forKey: kReminderDones)
            reminder.saveEventually()
        }
        var key = reminder.key()
        nc.postNotificationName(kRemindersChangedNotification, object: RemindersChanged(updates: nil, inserts: nil, deletes: [key]))
        self.reminderMap.removeValueForKey(key)
        self.loadSet.removeObject(key)
        self.loadErrorSet.removeObject(key)
        PFQuery.clearAllCachedResults()
    }
    
    func saveReminder(reminder:Reminder, resultBlock:PFBooleanResultBlock?) {
        var key = reminder.key() 
        assert(!self.loadSet.containsObject(key))
        self.loadSet.addObject(key)
        self.reminderMap[reminder.key()] = reminder
        self.nc.postNotificationName(kRemindersChangedNotification, object: RemindersChanged(updates: nil, inserts: [key], deletes: nil))
        self.nc.postNotificationName(kReminderLoadingNotification, object: key)
        reminder.saveInBackgroundWithBlock { (success:Bool, error:NSError!) -> Void in
            if success {
                self.loadErrorSet.removeObject(key)
            }else {
                self.loadErrorSet.addObject(key)
            }
            self.loadSet.removeObject(key)
            //add with new key so merge will fire update notification
            self.reminderMap[reminder.key()] = reminder
            self.mergeReminders([reminder])
            self.nc.postNotificationName(kReminderLoadingFinishedNotification, object: key)
            self.reminderMap.removeValueForKey(key)
            resultBlock?(success,error)
        }
        PFQuery.clearAllCachedResults()
    }
    
    func isReminderLoadingWithKey(key:String) -> Bool {
        if self.loadSet.containsObject(key) {
            return true
        }
        if self.remoteNotificationSet.containsObject(key){
            return true
        }
        return false
    }
    
    func isThereErrorForKey(key:String) -> Bool {
        return self.loadErrorSet.containsObject(key)
    }
}

class LocalNotificationsManager : NSObject{
    
    func updateForkey(key:String,alertBodyOption:String?,fireDateOption:NSDate?){
        self.setLocalNotificationForKey(key, alertBodyOption: alertBodyOption, fireDateOption: fireDateOption)
    }
    func deleteForKey(key:String) {
        self.deleteForKey(key)
    }
    
    func getLocationNotificationForKey(key:String) -> UILocalNotification?{
        var localNotifications = UIApplication.sharedApplication().scheduledLocalNotifications as [UILocalNotification]
        for notification in localNotifications {
            if let userInfo = notification.userInfo as NSDictionary? {
                if let objectId =  userInfo.objectForKey("reminderId") as? String {
                    if objectId == key {
                        return notification
                    }
                }
            }
        }
        return nil
    }
    
    func setLocalNotificationForKey(key:String,alertBodyOption:String?,fireDateOption:NSDate?){
        // check if already exists
        if let notification = self.getLocationNotificationForKey(key){
            var cancel = false
            if alertBodyOption == nil  || notification.alertBody != alertBodyOption! {
                cancel = true
            }
            if fireDateOption == nil || !notification.fireDate!.isEqualToDate(fireDateOption!) {
                cancel = true
            }
            if cancel {
                UIApplication.sharedApplication().cancelLocalNotification(notification)
            }else {
                // not modified
                return
            }
        }
        var now = NSDate()
        if fireDateOption == nil || alertBodyOption == nil || fireDateOption!.laterDate(now) == now {
            return
        }
        var  notification = UILocalNotification()
        notification.alertBody = alertBodyOption!
        notification.fireDate = fireDateOption!
        notification.userInfo =  NSDictionary(object: key, forKey: "reminderId")
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
    }
    
    func cancelLocalNotificationForKey(key:String){
        if let localNotification = self.getLocationNotificationForKey(key) {
            UIApplication.sharedApplication().cancelLocalNotification(localNotification)
        }
    }
}