//
//  ReminderManager.swift
//  udo
//
//  Created by Osman Alpay on 12/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

var kReminderCreatedNotification = "kReminderCreatedNotification"
var kRemindersChangedNotification = "kRemindersChangedNotification"
var kReminderLoadingNotification = "kReminderLoadingNotification"
var kReminderLoadingFinishedNotification = "kReminderLoadingFinishedNotification"
var kReminderShowNotification = "kReminderShowNotification"

class RemindersChanged {
    var isLocalChange:Bool
    var updates:[String]!
    var inserts:[String]!
    var deletes:[String]!
    
    init() {
        self.updates = []
        self.inserts = []
        self.deletes = []
        self.isLocalChange = false
    }
    
    convenience init(updates:[String]!,inserts:[String]!,deletes:[String]!){
        self.init()
        if updates != nil {
            self.updates = updates
        }
        if inserts != nil {
            self.inserts = inserts
        }
        if deletes != nil {
            self.deletes = deletes
        }
    }
    
    func hasKeyInUpdateSet(key:String) -> Bool {
        var index = (self.updates as NSArray).indexOfObject(key)
        return index != NSNotFound
    }
}

enum ReminderState : Int {
    case ReceivedNew
    case ReceivedUpdated
    case Seen
}

class ReminderManager : EventStoreManagerDelegate{
    private var reminderMap = Dictionary<String,Reminder>()
    private var lastUpdated = NSDate(timeIntervalSince1970: 0)
    private var remoteNotificationSet = NSMutableSet()
    private var loadSet = NSMutableSet()
    private var loadErrorSet = NSMutableSet()
    
    private var nc = NSNotificationCenter.defaultCenter()
    
    private var localNotificationManager = LocalNotificationsManager()
    private var eventStoreManager = EventStoreManager()
    
    private var userDefaults = NSUserDefaults.standardUserDefaults()
    
    private var reminderLastSeen: NSMutableDictionary!
    
    class var sharedInstance : ReminderManager {
        struct Static {
            static let instance : ReminderManager = ReminderManager()
        }
        return Static.instance
    }
    
    
    init() {
        self.eventStoreManager.delegate = self
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "userLoggedIn:", name: kUserLoggedInNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "userLoggedOut:", name: kUserLoggedOutNotification, object: nil)
        
        var userReminderLastSeen = self.userDefaults.objectForKey(kReminderLastUpdate) as? NSDictionary
        if userReminderLastSeen != nil {
            self.reminderLastSeen = userReminderLastSeen!.mutableCopy() as NSMutableDictionary
        }else {
            self.reminderLastSeen = NSMutableDictionary()
        }
    }
    
    func applicationDidFinishLaunchingNotification() {
        if PFUser.currentUser() != nil {
            self.fetchNewData(kPFCachePolicyNetworkOnly, resultBlock: { (_, _) -> Void in
            })
        }
    }
    
    func applicationWillEnterForeground() {
        if PFUser.currentUser() != nil {
            self.fetchNewData(kPFCachePolicyNetworkOnly, resultBlock: { (_, _) -> Void in
            })
            self.eventStoreManager.reset()
        }
    }
    
    private func notifyLoadForRemoteNotifications(){
        for key in self.remoteNotificationSet{
            self.loadSet.removeObject(key)
            self.remoteNotificationSet.removeObject(key)
            self.nc.postNotificationName(kReminderLoadingFinishedNotification, object: key)
        }
    }
    
    @objc func userLoggedIn(notification:NSNotification){
        self.fetchNewData(kPFCachePolicyNetworkOnly, resultBlock: nil)
    }
    
    @objc func userLoggedOut(notification:NSNotification){
        PFQuery.clearAllCachedResults()
        self.reminderMap.removeAll(keepCapacity: true)
        self.loadErrorSet.removeAllObjects()
        self.loadSet.removeAllObjects()
        self.remoteNotificationSet.removeAllObjects()
        self.lastUpdated = NSDate(timeIntervalSince1970: 0)
        self.localNotificationManager.removeAll()
        self.eventStoreManager.removeAll()
    }
    
    func requestAccessToEventStore(callerCompletion: ((Bool,NSError!)->Void)!){
        self.eventStoreManager.requestAccess { (success:Bool, error:NSError!) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                callerCompletion(success,error)
            })
        }
    }
    
    func itemChangedInStore(key: String!) {
        var change = RemindersChanged(updates: [key], inserts: nil, deletes: nil)
        var reminder = self.getReminder(key)
        self.setAlarmDataToReminder(reminder)
        self.nc.postNotificationName(kRemindersChangedNotification, object: change)
    }
    
    private func mergeCurrentRemindersWithReminders(reminders:NSArray){
        var updates = [String]()
        var inserts = [String]()
        for r in reminders {
            let reminder = r as Reminder
            var reminderId = reminder.key()
            if let reminder = self.reminderMap[reminderId]{
                if reminder.updatedAt != nil && reminder.updatedAt.laterDate(reminder.updatedAt) == reminder.updatedAt {
                    updates.append(reminderId)
                }
            } else {
                inserts.append(reminderId)
            }
            self.reminderMap[reminderId] = reminder
        }
        if updates.count > 0 || inserts.count > 0 {
            var change = RemindersChanged(updates: updates, inserts: inserts, deletes: nil)
            self.nc.postNotificationName(kRemindersChangedNotification, object: change)
        }
    }
    
    func setAlarmDataToReminder(reminder:Reminder){
        reminder.isOnReminders = self.eventStoreManager.isStored(reminder.key())
        if reminder.isOnReminders {
            reminder.alarmDate = self.eventStoreManager.getAlarmDateForKey(reminder.key())
        }
    }
    
    func deleteReminderSeen(reminderId:String){
        self.reminderLastSeen.removeObjectForKey(reminderId)
        self.userDefaults.setObject(self.reminderLastSeen, forKey: kReminderLastUpdate)
    }
    
    func setReminderAsSeen(reminderId:String){
        let reminder = self.getReminder(reminderId)
        if  reminder == nil || reminder.objectId == nil || reminder.updatedAt == nil {
            //not saved yet
            return
        }
        self.reminderLastSeen.setObject(reminder.updatedAt, forKey: reminder.objectId)
        self.userDefaults.setObject(self.reminderLastSeen, forKey: kReminderLastUpdate)
    }
    
    func getReminderState(reminderId:String) -> ReminderState {
        let reminder = self.getReminder(reminderId)
        if reminder.objectId == nil {
            //not saved yet
            return ReminderState.Seen
        }
        if reminder.updatedAt == nil{
            return ReminderState.ReceivedNew
        }
        if let lastSeen = self.reminderLastSeen.objectForKey(reminderId) as? NSDate{
            if lastSeen.isEqualToDate(reminder.updatedAt) || lastSeen.laterDate(reminder.updatedAt) == lastSeen {
                return ReminderState.Seen
            }
            return ReminderState.ReceivedUpdated
        }
        return ReminderState.ReceivedNew
    }
    
    
    private func fetchNewData(cachePolicy:PFCachePolicy, resultBlock:PFArrayResultBlock?){
        let remindersQuery = Reminder.query()
        remindersQuery.whereKey(kReminderCollaborators,equalTo:PFUser.currentUser().username)
        remindersQuery.whereKey("updatedAt", greaterThan: self.lastUpdated)
        remindersQuery.orderByDescending("updatedAt")
        remindersQuery.cachePolicy = cachePolicy
        remindersQuery.findObjectsInBackgroundWithBlock({
            (resultData:[AnyObject]!, error: NSError!) -> Void in
            if error == nil{
                var newReminders = NSMutableArray()
                for reminder in resultData as [Reminder]{
                    if let existingReminder = self.getReminder(reminder.key()){
                        if let updatedAt = existingReminder.updatedAt {
                            if existingReminder.updatedAt.isEqualToDate(reminder.updatedAt) {
                                // already have this version
                                break
                            }
                        }
                    }
                    newReminders.addObject(reminder)
                    if self.lastUpdated.compare(reminder.updatedAt) == NSComparisonResult.OrderedAscending {
                        self.lastUpdated = reminder.updatedAt
                    }
                    self.setLocalNotification(reminder.key(), title: reminder.title, fireDate: reminder.dueDate,repeatInterval: reminder.dueDateInterval)
                    self.setAlarmDataToReminder(reminder)
                }
                self.mergeCurrentRemindersWithReminders(newReminders)
            }else{
                //handle error
                println("e:fetchNewData: \(error)")
                if error.code != kPFErrorCacheMiss {
                    TSMessage.showNotificationWithTitle("Could not connect to server", type: TSMessageNotificationType.Error)
                }
            }
            // remove all remote notifications it might been deleted from server
            self.notifyLoadForRemoteNotifications()
            if error == nil && resultData.count > 0   {
                // sync user
                PFCloud.callFunctionInBackground("syncUserCheck", withParameters:NSDictionary(object: self.lastUpdated, forKey: "time")) {
                    (result: AnyObject!, error: NSError!) -> Void in
                    resultBlock?(resultData,error)
                    return
                }
            }else {
                resultBlock?(resultData,error)
            }
        })
    }
    
    func cancelLocalNotification(key:String){
        self.localNotificationManager.cancelLocalNotificationForKey(key)
    }
    
    func setLocalNotification(key:String,title:String!,fireDate:NSDate?, repeatInterval:NSNumber?){
        self.localNotificationManager.setLocalNotificationForKey(key, alertBodyOption: "\(title) due time!", fireDateOption: fireDate,repeatInterval:repeatInterval)
    }
    
    func cancelNotification(key:String){
        self.localNotificationManager.cancelLocalNotificationForKey(key)
    }
    
    func reminderChangedPushNotificationReceived(reminderId:String!,userInfo:NSDictionary!, completionHandler:(UIBackgroundFetchResult) -> Void ){
        self.remoteNotificationSet.addObject(reminderId)
        self.loadSet.addObject(reminderId)
        var dueDate:NSDate?
        if let dueDateString = userInfo["d"] as? String {
            dueDate = NSDate(fromISO8601String: dueDateString)
        }
        var title = userInfo["t"] as? String
        var reminder = self.getReminder(reminderId)
        if reminder == nil {
            reminder = Reminder() //temp
            reminder.objectId = reminderId
            reminder.title = title
            reminder.dueDate = dueDate
            reminder.collaborators = []
            self.reminderMap[reminderId] = reminder
            var change = RemindersChanged(updates: nil, inserts: [reminder.key()], deletes: nil)
            self.nc.postNotificationName(kRemindersChangedNotification, object: change)
        }
        var repeatInterval = userInfo["i"] as? NSNumber
        self.setLocalNotification(reminderId, title: title!, fireDate: dueDate,repeatInterval: repeatInterval)
        nc.postNotificationName(kReminderLoadingNotification, object: reminderId)
    }
    
    func getUsernameFromNotification(userInfo:NSDictionary!) -> String? {
        if let username = userInfo["u"] as? String{
            return ContactsManager.sharedInstance.getUDContactForUserId(username).name()
        }else {
            return nil
        }
    }
    
    func localNotificationRecevied(application:UIApplication,notification: UILocalNotification){
        let reminderId = notification.userInfo?["reminderId"] as? NSString
        if application.applicationState == UIApplicationState.Active {
            JSQSystemSoundPlayer.jsq_playMessageReceivedAlert()
            TSMessage.showNotificationWithTitle(notification.alertBody, type: TSMessageNotificationType.Warning, duration: -1 , callback: { () -> Void in
                if reminderId != nil {
                    TSMessage.dismissActiveNotification()
                    self.nc.postNotificationName(kReminderShowNotification, object: reminderId)
                }
            })
        }else if application.applicationState == UIApplicationState.Inactive {
            if reminderId != nil {
                self.nc.postNotificationName(kReminderShowNotification, object: reminderId)
            }
        }
    }
    
    func remoteNotificationReceived(command:PushCommand,applicationState:UIApplicationState, userInfo:NSDictionary!, completionHandler:(UIBackgroundFetchResult) -> Void ){
        var reminderId = userInfo["r"] as? String
        if reminderId == nil {
            println("e:remoteNotificationReceived:reminderId is empty")
            return
        }
        var alertMsg:String!
        var alertType:TSMessageNotificationType!
        var username = self.getUsernameFromNotification(userInfo)!
        switch command {
        case PushCommand.New, PushCommand.Update:
            self.reminderChangedPushNotificationReceived(reminderId, userInfo: userInfo,completionHandler: completionHandler)
            if command == PushCommand.New {
                alertMsg = "\(username) send you a new reminder"
            }else {
                alertMsg = "\(username) updated a reminder"
            }
            alertType = TSMessageNotificationType.Warning
        case PushCommand.Delivery:
            // only admin will see the delivery receipt messages
            var reminder = self.getReminder(reminderId!)
            if reminder.isCurrentUserAdmin() {
                alertMsg = "\(username) received your reminder"
                alertType = TSMessageNotificationType.Success
            }
        case PushCommand.Done:
            alertMsg = "\(username) completed a reminder"
            alertType = TSMessageNotificationType.Success
        case PushCommand.Undone:
            alertMsg = "\(username) uncompleted a reminder"
            alertType = TSMessageNotificationType.Warning
        default:
            println("noting to do")
        }
        if applicationState == UIApplicationState.Active  {
            // show message
            if alertMsg != nil {
                JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
                TSMessage.showNotificationWithTitle(alertMsg, type: alertType, duration: 0,  callback: { () -> Void in
                    if reminderId != nil {
                        self.nc.postNotificationName(kReminderShowNotification, object: reminderId)
                    }
                })
            }
            // refresh data
            self.refresh({ (resultData:[AnyObject]!, error:NSError!) -> Void in
                if error != nil {
                    completionHandler(UIBackgroundFetchResult.Failed)
                }else if resultData.count > 0 {
                    completionHandler(UIBackgroundFetchResult.NewData)
                }else{
                    completionHandler(UIBackgroundFetchResult.NoData)
                }
            })
        }else if applicationState == UIApplicationState.Background {
            // background
            if reminderId != nil {
                // send received
                var replyReminder = Reminder(withoutDataWithObjectId: reminderId)
                replyReminder.addUniqueObject(PFUser.currentUser().username, forKey: "received")
                replyReminder.saveInBackgroundWithBlock({ (_, _) -> Void in
                    completionHandler(UIBackgroundFetchResult.NewData)
                })
            } else {
                completionHandler(UIBackgroundFetchResult.NoData)
            }
        }
    }
    
    func refresh(resultBlock:PFArrayResultBlock?){
        self.fetchNewData(kPFCachePolicyNetworkOnly, resultBlock: resultBlock)
    }
    
    func getReminderKeys() -> NSArray! {
        return self.reminderMap.keys.array
    }
    
    func getReminder(key:String) -> Reminder! {
        return self.reminderMap[key]
    }
    
    func deleteReminder(key:String) {
        assert(!self.loadSet.containsObject(key))
        var reminder = self.getReminder(key)
        if reminder.objectId != nil {
            reminder.removeObject(PFUser.currentUser().username, forKey: kReminderCollaborators)
            reminder.removeObject(PFUser.currentUser().username, forKey: kReminderDones)
            reminder.saveEventually()
        }
        var key = reminder.key()
        nc.postNotificationName(kRemindersChangedNotification, object: RemindersChanged(updates: nil, inserts: nil, deletes: [key]))
        self.deleteReminderSeen(key)
        self.eventStoreManager.remove(key)
        self.cancelNotification(key)
        self.reminderMap.removeValueForKey(key)
        self.loadSet.removeObject(key)
        self.loadErrorSet.removeObject(key)
    }
    
    func updateEventStore(reminder:Reminder,addToMyReminders:Bool,alarmDate:NSDate!,repeatInterval:NSCalendarUnit!){
        if addToMyReminders {
            self.eventStoreManager.upsertWithTitle(reminder.title, andAlarmDate: alarmDate,andRepeatInterval:repeatInterval, forKey: reminder.key())
        }else if self.eventStoreManager.isStored(reminder.key()){
            self.eventStoreManager.remove(reminder.key())
        }
    }
    
    func retrySaving(reminderKey:String){
        var reminder = self.getReminder(reminderKey)
        self.saveReminder(reminder, resultBlock: nil)
    }
    
    func saveReminder(reminder:Reminder,addToMyReminders:Bool,alarmDate:NSDate!,repeatInterval:NSCalendarUnit! ,resultBlock:PFBooleanResultBlock?) {
        if !reminder.isDirty() {
            self.updateEventStore(reminder, addToMyReminders: addToMyReminders, alarmDate: alarmDate, repeatInterval: repeatInterval)
            resultBlock?(true,nil)
            return
        }
        reminder.isOnReminders = addToMyReminders
        reminder.alarmDate = alarmDate
        reminder.received = [PFUser.currentUser().username]
        self.saveReminder(reminder, resultBlock: { (success:Bool, error:NSError!) -> Void in
            if success {
                self.updateEventStore(reminder, addToMyReminders: addToMyReminders, alarmDate: alarmDate,repeatInterval: repeatInterval)
                if !reminder.isCurrentUserDone() {
                    self.setLocalNotification(reminder.key(), title: reminder.title, fireDate: reminder.dueDate, repeatInterval: reminder.dueDateInterval)
                }else {
                    self.cancelLocalNotification(reminder.key())
                }
            }
            resultBlock?(success,error)
        })
    }
    
    func changeReminderStatusForCurrentUser(key:String, done:Bool,resultBlock:PFBooleanResultBlock?){
        if let reminder = self.getReminder(key) {
            if done == true {
                reminder.setUserDone()
            }else{
                reminder.setUserUnDone()
            }
            self.saveReminder(reminder, resultBlock: { (success:Bool, error:NSError!) -> Void in
                resultBlock?(success,error)
                return
            })
        }
    }
    
    
    private func saveReminder(reminder:Reminder,resultBlock:PFBooleanResultBlock?) {
        var key = reminder.key()
        assert(!self.loadSet.containsObject(key))
        self.loadSet.addObject(key)
        var change = RemindersChanged()
        change.isLocalChange = true
        if self.reminderMap[key] == nil{
            //new reminder
            self.reminderMap[key] = reminder
            change.inserts = [key]
        }else {
            change.updates = [key]
        }
        reminder.failedToSave = false
        self.nc.postNotificationName(kRemindersChangedNotification, object: change)
        self.nc.postNotificationName(kReminderLoadingNotification, object: key)
        reminder.saveInBackgroundWithBlock { (success:Bool, error:NSError!) -> Void in
            if success {
                JSQSystemSoundPlayer.jsq_playMessageSentSound()
                self.loadErrorSet.removeObject(key)
                if key != reminder.key() {
                    // key changed add new one
                    self.reminderMap[reminder.key()] = reminder
                    self.setReminderAsSeen(reminder.key())
                    // remove old key
                    self.reminderMap.removeValueForKey(key)
                    // notify listeners
                    self.nc.postNotificationName(kReminderCreatedNotification, object: NSDictionary(objects: [key,reminder.key()], forKeys: ["oldKey","newKey"]))
                    
                }else{
                    self.setReminderAsSeen(key)
                }
            }else {
                reminder.failedToSave = true
                self.loadErrorSet.addObject(key)
                TSMessage.showNotificationWithTitle("Error while saving reminder", subtitle: error.localizedDescription, type: TSMessageNotificationType.Error)
            }
            self.loadSet.removeObject(key)
            self.nc.postNotificationName(kReminderLoadingFinishedNotification, object: reminder.key())
            resultBlock?(success,error)
        }
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
    
    
    // sorting
    func unseenComparator(r1:Reminder,r2:Reminder) -> NSComparisonResult? {
        var comparisonResult:NSComparisonResult?
        if self.getReminderState(r1.key()) == ReminderState.Seen {
            if self.getReminderState(r2.key())  == ReminderState.Seen {
                // comparisonResult = self.dueDateComparator(r1, r2: r2)
            }else{
                comparisonResult = NSComparisonResult.OrderedAscending
            }
        }else {
            if self.getReminderState(r2.key()) == ReminderState.Seen{
                comparisonResult = NSComparisonResult.OrderedDescending
            }
        }
        return comparisonResult
    }
    
    func dueDateComparator(r1:Reminder,r2:Reminder) -> NSComparisonResult? {
        let now = NSDate()
        let r1Done = r1.isCurrentUserDone()
        let r2Done = r2.isCurrentUserDone()
        if r1Done && !r2Done {
            return NSComparisonResult.OrderedAscending
        }else if !r1Done && r2Done {
            return NSComparisonResult.OrderedDescending
        }else{
            let r1Completed = r1.completed()
            let r2Completed = r2.completed()
            if r1Completed && !r2Completed {
                return NSComparisonResult.OrderedAscending
            }else if !r1Completed && r2Completed {
                return NSComparisonResult.OrderedDescending
            }
        }
        var comparisonResult:NSComparisonResult?
        if let r1DueDate = r1.dueDate {
            if let r2DueDate = r2.dueDate {
                comparisonResult =  r2.dueDate.compare(r1.dueDate)
            }else {
                comparisonResult =  NSComparisonResult.OrderedDescending
            }
        }else{
            if let r2DueDate = r2.dueDate {
                comparisonResult = NSComparisonResult.OrderedAscending
            }
        }
        return comparisonResult
    }
    func updatedAtComparator(r1:Reminder,r2:Reminder) -> NSComparisonResult? {
        var comparisonResult:NSComparisonResult?
        if let r1UpdatedAt = r1.updatedAt {
            if let r2UpdatedAt = r2.updatedAt {
                comparisonResult =  r1UpdatedAt.compare(r2UpdatedAt)
            }else {
                comparisonResult =  NSComparisonResult.OrderedDescending
            }
        }else{
            if let r2UpdatedAt = r2.updatedAt {
                comparisonResult = NSComparisonResult.OrderedAscending
            }
        }
        return comparisonResult
    }
    
    func reminderComparator(key1:AnyObject!,key2:AnyObject!) -> NSComparisonResult {
        let r1 = self.getReminder(key1 as String)
        let r2 = self.getReminder(key2 as String)
        // sort by unseen
        var comparisonResult:NSComparisonResult!
        comparisonResult = self.unseenComparator(r1, r2: r2)
        
        // sort by due date
        if comparisonResult ==  nil {
            comparisonResult =  self.dueDateComparator(r1, r2: r2)
        }
        // sort by updated at
        if comparisonResult ==  nil {
            comparisonResult = self.updatedAtComparator(r1, r2: r2)
        }
        if comparisonResult != nil {
            return NSComparisonResult(rawValue: (0 - comparisonResult.rawValue))!
        }
        return NSComparisonResult.OrderedSame
    }
    // sorting end
    
}

class LocalNotificationsManager : NSObject{
    
    func removeAll(){
        UIApplication.sharedApplication().cancelAllLocalNotifications()
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
    
    func setLocalNotificationForKey(key:String,alertBodyOption:String?,fireDateOption:NSDate?,repeatInterval:NSNumber?){
        // check if already exists
        if let notification = self.getLocationNotificationForKey(key){
            var cancel = false
            if alertBodyOption == nil  || notification.alertBody != alertBodyOption! {
                cancel = true
            }
            if (notification.fireDate != nil && fireDateOption == nil) || (notification.fireDate == nil && fireDateOption != nil) || !notification.fireDate!.isEqualToDate(fireDateOption!) {
                cancel = true
            }
            if (notification.repeatInterval != nil && repeatInterval == nil) || (notification.repeatInterval == nil && repeatInterval != nil) || notification.repeatInterval.rawValue != repeatInterval{
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
        if repeatInterval != nil {
            notification.repeatInterval = NSCalendarUnit(repeatInterval!.unsignedLongValue)
        }
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