//
//  ReminderManager.swift
//  udo
//
//  Created by Osman Alpay on 12/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

var kUserSyncStarted = "kUserSyncStarted"
var kUserSyncEnded = "kUserSyncEnded"

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
    private var reminderMap = NSMutableDictionary()
    private var lastUpdated = NSDate(timeIntervalSince1970: 0)
    private var lastNotificationReceivedWithDate = NSDate(timeIntervalSince1970: 0)
    private var remoteNotificationSet = NSMutableSet()
    private var loadSet = NSMutableSet()
    private var loadErrorSet = NSMutableSet()
    
    private var nc = NSNotificationCenter.defaultCenter()
    
    private var localNotificationManager = LocalNotificationsManager()
    private var eventStoreManager = EventStoreManager()
    private var notesManager = NotesManager()
    
    private var userDefaults = NSUserDefaults.standardUserDefaults()
    
    private var reminderLastSeen: NSMutableDictionary!
    
    class var sharedInstance : ReminderManager {
        struct Static {
            static let instance : ReminderManager = ReminderManager()
        }
        return Static.instance
    }
    
    var isSyncing = false
    
    
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
            self.syncUser(nil)
        }
    }
    
    func applicationWillEnterForeground() {
        self.notesManager.applicationWillEnterForeground()
        if PFUser.currentUser() != nil {
            self.syncUser(nil)
            self.eventStoreManager.reset()
            var updates = [String]()
            for reminder in self.reminderMap.allValues as [Reminder] {
                if self.setAlarmDataToReminder(reminder) {
                    updates.append(reminder.key())
                }
            }
            if updates.count > 0 {
                var change = RemindersChanged(updates: updates, inserts: nil, deletes: nil)
                change.isLocalChange = true
                self.nc.postNotificationName(kRemindersChangedNotification, object: change)
            }
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
        self.syncUser(nil)
    }
    
    @objc func userLoggedOut(notification:NSNotification){
        PFQuery.clearAllCachedResults()
        self.reminderMap.removeAllObjects()
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
    
    private func mergeCurrentRemindersWithReminders(reminders:NSArray) -> RemindersChanged{
        var updates = [String]()
        var inserts = [String]()
        for reminder in reminders as [Reminder]{
            var reminderId = reminder.key()
            if let reminder = self.getReminder(reminderId){
                if reminder.updatedAt != nil && reminder.updatedAt.laterDate(reminder.updatedAt) == reminder.updatedAt {
                    updates.append(reminderId)
                }
            } else {
                inserts.append(reminderId)
            }
            self.setLocalNotification(reminder.key(), title: reminder.title, fireDate: reminder.dueDate,repeatInterval: reminder.dueDateInterval)
            self.setAlarmDataToReminder(reminder)
            self.reminderMap.setObject(reminder, forKey: reminderId)
        }
        if let lastReminder = reminders.firstObject as? Reminder {
            self.lastUpdated = lastReminder.updatedAt
        }
        return RemindersChanged(updates: updates, inserts: inserts, deletes: nil)
    }
    
    func setAlarmDataToReminder(reminder:Reminder) -> Bool {
        var isChanged = false
        let isOnReminders = self.eventStoreManager.isStored(reminder.key())
        isChanged = reminder.isOnReminders != isOnReminders
        reminder.isOnReminders = isOnReminders
        if reminder.isOnReminders {
            let eAlarmDate = self.eventStoreManager.getAlarmDateForKey(reminder.key())
            isChanged = isChanged || (eAlarmDate != reminder.alarmDate)
            reminder.alarmDate = eAlarmDate
        }else {
            reminder.alarmDate = nil
        }
        return isChanged
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
    
    func syncUserCheck(){
        PFCloud.callFunctionInBackground("userReceivedLastUpdate", withParameters:NSDictionary(object: self.lastUpdated, forKey: "time")) {
            (result: AnyObject!, error: NSError!) -> Void in
            if error != nil {
                println("e:syncUserCheck:\(error.localizedDescription)")
            }
        }
    }
    
    func showConnectionError(){
        TSMessage.showNotificationWithTitle("Could not connect to server", type: TSMessageNotificationType.Error)
    }
    
    func loadReminders(callback:PFIdResultBlock?){
        self.nc.postNotificationName(kUserSyncStarted, object: nil)
        var query = Reminder.query()
        query.whereKey("collaborators", equalTo: PFUser.currentUser().username)
        query.whereKey("updatedAt", greaterThan: self.lastUpdated)
        query.orderByDescending("updatedAt")
        query.findObjectsInBackgroundWithBlock { (result:[AnyObject]!, error:NSError!) -> Void in
            if error != nil{
                self.showConnectionError()
            } else if result.count > 0{
                let change = self.mergeCurrentRemindersWithReminders(result)
                self.nc.postNotificationName(kRemindersChangedNotification, object: change)
                self.syncUserCheck()
                self.notifyLoadForRemoteNotifications()
            }
            self.nc.postNotificationName(kUserSyncEnded, object: nil)
            callback?(result,error)
        }
    }
    
    
    private func syncUser(callback:PFIdResultBlock?){
        self.nc.postNotificationName(kUserSyncStarted, object: nil)
        var params = NSMutableDictionary()
        params.setObject(self.notesManager.getLastNoteCreatedAtForReminders(), forKey:"lastNoteCreatedAt" )
        params.setObject(self.lastUpdated, forKey: "lastReminderUpdatedAt")
        self.isSyncing = true
        PFCloud.callFunctionInBackground("syncUser", withParameters:params) {
            (result: AnyObject!, error: NSError!) -> Void in
            if error != nil{
                self.showConnectionError()
            }else {
                let responseData = result as NSDictionary
                // sync notes
                let reminderNotes = responseData.objectForKey("rn") as NSDictionary
                let updatedNotesSet = self.notesManager.syncUserWith(reminderNotes)
                
                // sync reminders
                let reminders = responseData.objectForKey("r") as NSArray
                let change = self.mergeCurrentRemindersWithReminders(reminders)
                // add updated notes to change set
                updatedNotesSet.minusSet(NSSet(array: change.inserts))
                updatedNotesSet.minusSet(NSSet(array: change.updates))
                for noteId in updatedNotesSet.allObjects as [String]{
                    change.updates.append(noteId)
                }
                self.nc.postNotificationName(kRemindersChangedNotification, object: change)
                
                // remove all remote notifications it might been deleted from server
                self.notifyLoadForRemoteNotifications()
                if reminders.count > 0   {
                    self.syncUserCheck()
                }
            }
            self.isSyncing = false
            self.nc.postNotificationName(kUserSyncEnded, object: nil)
            callback?(result,error)
        }
        
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
    
    
    func reminderChangedPushNotificationReceived(pushInfo:PushNotificationUserInfo){
        self.remoteNotificationSet.addObject(pushInfo.reminderId)
        self.loadSet.addObject(pushInfo.reminderId)
        var reminder = self.getReminder(pushInfo.reminderId)
        if reminder == nil {
            reminder = Reminder() //temp
            reminder.isPlaceHolder = true
            reminder.objectId = pushInfo.reminderId
            reminder.collaborators = []
            self.reminderMap.setObject(reminder, forKey: pushInfo.reminderId)
            var change = RemindersChanged(updates: nil, inserts: [pushInfo.reminderId], deletes: nil)
            self.nc.postNotificationName(kRemindersChangedNotification, object: change)
        }
        reminder.title = pushInfo.reminderTitle
        reminder.dueDate = pushInfo.reminderDueDate
        reminder.dueDateInterval = pushInfo.reminderDueDateInterval
        self.setLocalNotification(pushInfo.reminderId, title: reminder.title, fireDate: reminder.dueDate,repeatInterval: reminder.dueDateInterval)
        nc.postNotificationName(kReminderLoadingNotification, object: pushInfo.reminderId)
    }
    
    func showAlertForPushNotification(pushInfo:PushNotificationUserInfo){
        var alertMsg:String!
        var alertType = TSMessageNotificationType.Warning
        var senderName = ContactsManager.sharedInstance.getUDContactForUserId(pushInfo.senderId).name()
        switch pushInfo.command! {
        case PushCommand.New:
            alertMsg = "\(senderName) send you a new reminder"
        case  PushCommand.Update:
            alertMsg = "\(senderName) updated a reminder"
        case PushCommand.Delivery:
            // only admin will see the delivery receipt messages
            if let reminder = self.getReminder(pushInfo.reminderId) {
                if reminder.isCurrentUserAdmin() {
                    alertMsg = "\(senderName) received your reminder"
                    alertType = TSMessageNotificationType.Success
                }
            }
        case PushCommand.Done:
            alertMsg = "\(senderName) completed a reminder"
            alertType = TSMessageNotificationType.Success
        case PushCommand.Undone:
            alertMsg = "\(senderName) uncompleted a reminder"
        default:
            println("noting to do")
        }
        // show message
        if alertMsg != nil {
            JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
            TSMessage.showNotificationWithTitle(alertMsg, type: alertType, duration: 0,  callback: { () -> Void in
                if pushInfo.reminderId != nil {
                    self.nc.postNotificationName(kReminderShowNotification, object: pushInfo.reminderId)
                }
            })
        }
    }
    
    func sendReceivedReceipt(pushInfo:PushNotificationUserInfo!,completionHandler:(UIBackgroundFetchResult) -> Void )  {
        // send received
        var replyReminder = Reminder(withoutDataWithObjectId: pushInfo.reminderId)
        replyReminder.addUniqueObject(PFUser.currentUser().username, forKey: "received")
        replyReminder.saveInBackgroundWithBlock({ (_, _) -> Void in
            completionHandler(UIBackgroundFetchResult.NewData)
        })
    }
    
    func remoteNotificationReceived(pushInfo:PushNotificationUserInfo!,application:UIApplication,fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void){
        if pushInfo.command == PushCommand.New || pushInfo.command == PushCommand.Update || pushInfo.command == PushCommand.Done || pushInfo.command == PushCommand.Undone{
            self.reminderChangedPushNotificationReceived(pushInfo)
            if application.applicationState == UIApplicationState.Active  {
                self.showAlertForPushNotification(pushInfo)
                self.loadReminders({ (_, _) -> Void in
                    completionHandler(UIBackgroundFetchResult.NewData)
                })
            }else if application.applicationState == UIApplicationState.Background {
                self.sendReceivedReceipt(pushInfo, completionHandler: completionHandler)
            }
        }else if pushInfo.command == PushCommand.Note {
            self.notesManager.remoteReminderNoteNotificationReceived(pushInfo)
            if application.applicationState == UIApplicationState.Active  {
                self.notesManager.showAlertForPushNotification(pushInfo)
                self.notesManager.loadNotes(pushInfo.reminderId, tryCount: 0)
                completionHandler(UIBackgroundFetchResult.NewData)
            }else {
                completionHandler(UIBackgroundFetchResult.NoData)
            }
        }
        if application.applicationState == UIApplicationState.Inactive {
            // opened from notification
            self.nc.postNotificationName(kReminderShowNotification, object: pushInfo.reminderId)
        }
    }
    
    func getReminderKeys() -> NSArray! {
        return self.reminderMap.allKeys
    }
    
    func getReminder(key:String) -> Reminder! {
        return self.reminderMap.objectForKey(key) as? Reminder
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
        self.reminderMap.removeObjectForKey(key)
        self.loadSet.removeObject(key)
        self.loadErrorSet.removeObject(key)
        self.notesManager.reminderDeleted(key)
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
                    self.reminderMap.removeObjectForKey(key)
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
            if self.getReminderState(r2.key())  != ReminderState.Seen {
                comparisonResult = NSComparisonResult.OrderedAscending
            }
        }else {
            if self.getReminderState(r2.key()) == ReminderState.Seen{
                comparisonResult = NSComparisonResult.OrderedDescending
            }
        }
        if comparisonResult == nil {
            let ur1  = self.notesManager.getReminderNotes(r1.key()).getUnreadMessageCount()
            let ur2 = self.notesManager.getReminderNotes(r2.key()).getUnreadMessageCount()
            if ur1 > 0 || ur2 > 0 {
                comparisonResult = self.updatedAtComparator(r1, r2: r2)
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
    
    // notes manager
    func loadEarlierNotesForReminder(reminderId:String){
        self.notesManager.loadEarlierNotesForReminderId(reminderId)
    }
    func getReminderNotes(reminderId:String) -> ReminderNotes! {
        return self.notesManager.getReminderNotes(reminderId)
    }
    func setNotesAsSeenForReminder(reminderId:String) {
        self.notesManager.setReminderNotesAsSeen(reminderId)
    }
    func sendNoteText(text:String, forReminderId:String){
        self.notesManager.addNote(text, forReminderId: forReminderId)
    }
    func trySendingNoteAgain(note:Note){
        self.notesManager.trySendingAgain(note)
    }
    
}

