//
//  NotesManager.swift
//  udo
//
//  Created by Osman Alpay on 27/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

var kReminderNoteUpdatesAvailableNotification = "kReminderNoteUpdatesAvailableNotification"
var kReminderNoteLoadingNotification = "kReminderNoteLoadingNotification"
var kReminderNoteLoadingFinishedNotification = "kReminderNoteLoadingFinishedNotification"
var kReminderNoteSaveFinishedNotification = "kReminderSaveFinishedNotification"
var kReminderNoteSavingNotification = "kReminderNoteSavingNotification"

var kReminderNoteLoadingEarlierNotification = "kReminderNoteLoadingEarlierNotification"
var kReminderNoteLoadingEarlierFinishedNotification = "kReminderNoteLoadingEarlierFinishedNotification"

var kNotesLastRead = "NotesLastRead"

class ReminderNoteSetting {
    var reminderId:String!
    var loadQuery:PFQuery!
    var receiveNotesQuery:PFQuery!
    var lastNoteCreatedAt:NSDate!
    private var notesArray:NSMutableArray!
    private var notesSet:NSMutableSet!
    
    let loadLimit = 100
    var loadSkip = 0
    
    init(reminderId:String) {
        self.reminderId = reminderId
        self.lastNoteCreatedAt = NSDate(timeIntervalSince1970: 0)
        self.notesArray = NSMutableArray()
        self.notesSet = NSMutableSet()
        self.loadQuery = ReminderNote.query()
        self.loadQuery.whereKey("reminderId",equalTo:reminderId)
        self.loadQuery.limit = loadLimit
        self.loadQuery.orderByDescending("createdAt")
        
        // do not receive my own messages after first load
        self.receiveNotesQuery = ReminderNote.query()
        self.receiveNotesQuery.whereKey("reminderId",equalTo:reminderId)
        self.receiveNotesQuery.whereKey("sender", notEqualTo: PFUser.currentUser().username)
        self.receiveNotesQuery.orderByDescending("createdAt")
    }
    
    func addNotes(notes:NSArray,sort:Bool){
        self.notesArray.addObjectsFromArray(notes)
        for note in notes as [ReminderNote]{
            if note.objectId != nil {
                self.notesSet.addObject(note.objectId)
            }
        }
        if sort{
            self.notesArray.sortUsingDescriptors([NSSortDescriptor(key: "createdAt", ascending: true)])
        }
    }
    
    func getLastNote() -> ReminderNote? {
        return self.notesArray.lastObject as? ReminderNote
    }
    
    func getNotes() -> NSArray{
        return self.notesArray.copy() as NSArray
    }
    
    func isExistingNote(noteId:String) -> Bool{
        return self.notesSet.containsObject(noteId)
    }
    
}

class NotesManager {
    class var sharedInstance : NotesManager {
        struct Static {
            static let instance : NotesManager = NotesManager()
        }
        return Static.instance
    }
    
    private var noteSettings = NSMutableDictionary()
    private var notificationPending = NSMutableDictionary()
    private var firstRequestAfterGoingBackground = NSMutableSet()
    private var loadingSet = NSMutableSet()
    private var nc = NSNotificationCenter.defaultCenter()
    
    private var numberOfConsecutiveLoadCalls = 0
    
    private var userDefaults = NSUserDefaults.standardUserDefaults()
    private var notesLastRead:NSMutableDictionary!
    
    init() {
        var userNoteLastRead = self.userDefaults.objectForKey(kNotesLastRead) as? NSDictionary
        if userNoteLastRead != nil {
            self.notesLastRead = userNoteLastRead!.mutableCopy() as NSMutableDictionary
        }else {
            self.notesLastRead = NSMutableDictionary()
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "remindersChangedNotification:", name: kRemindersChangedNotification, object: nil)
    }
    
    @objc func remindersChangedNotification(notification:NSNotification){
        var change = notification.object as RemindersChanged
        for key in change.deletes{
            self.notesLastRead.removeObjectForKey(key)
            self.userDefaults.setObject(self.notesLastRead, forKey: kNotesLastRead)
        }
    }
    
    func setReminderNotesAsSeen(reminderId:String){
        if let noteSettings = self.getSettingsForReminderId(reminderId) {
            if let lastNote = noteSettings.getLastNote() {
                self.notesLastRead.setValue(lastNote.date(), forKey: reminderId)
                self.userDefaults.setObject(self.notesLastRead, forKey: kNotesLastRead)
            }
        }
    }
    
    func getUnreadMessageCount(reminderId:String) -> Int{
        if let noteSettings = self.getSettingsForReminderId(reminderId) {
            let notes = noteSettings.getNotes()
            if let lastRead = self.notesLastRead.objectForKey(reminderId) as? NSDate {
                let range = NSMakeRange(0, notes.count)
                var index = notes.indexOfObject(lastRead, inSortedRange: range, options: NSBinarySearchingOptions.LastEqual, usingComparator: { (o, d) -> NSComparisonResult in
                    let note = o as ReminderNote
                    return note.date().compare(d as NSDate)
                })
                if index == NSNotFound {
                    return 0
                }
                // dont count the notes sent by me
                var unread = 0
                var me = PFUser.currentUser().username
                for ( index++; index < notes.count; index++){
                    let note = notes.objectAtIndex(index) as ReminderNote
                    if note.sender != me{
                        unread++
                    }
                }
                return unread
            }else{
                return notes.count
            }
        }else{
            return 0
        }
        
    }
    
    private func getSettingsForReminderId(reminderId:String) -> ReminderNoteSetting? {
        return self.noteSettings.objectForKey(reminderId) as? ReminderNoteSetting
    }
    
    private func findResultBlock(noteSetting:ReminderNoteSetting,notificationToPostAfter:String)(notes:[AnyObject]!, error:NSError!) -> Void {
        var shouldHaveMoreUpdates = false
        if error != nil {
            TSMessage.showNotificationWithTitle("Connection problem", type: TSMessageNotificationType.Error)
        }else {
            noteSetting.addNotes(notes,sort:true)
            
            if let lastNote = noteSetting.getLastNote() {
                noteSetting.lastNoteCreatedAt =  lastNote.createdAt
            }
            if notificationToPostAfter == kReminderNoteLoadingEarlierFinishedNotification {
                // find a better way to do this
                noteSetting.loadSkip = noteSetting.loadSkip + noteSetting.loadLimit
            }
            self.noteSettings.setObject(noteSetting, forKey: noteSetting.reminderId)
            if let reminderPendingNotifications = self.notificationPending.objectForKey(noteSetting.reminderId) as? NSMutableSet{
                for note in notes {
                    reminderPendingNotifications.removeObject(note.objectId)
                }
                if reminderPendingNotifications.count > 0{
                    //we still have updates
                    if numberOfConsecutiveLoadCalls > 3 {
                        //note is missing dont try anymore
                        reminderPendingNotifications.removeAllObjects()
                        numberOfConsecutiveLoadCalls = 0
                    }else{
                        shouldHaveMoreUpdates = true
                        numberOfConsecutiveLoadCalls++
                    }
                }else{
                    numberOfConsecutiveLoadCalls = 0
                }
            }
        }
        self.loadingSet.removeObject(noteSetting.reminderId)
        self.nc.postNotificationName(notificationToPostAfter, object: noteSetting.reminderId)
        if shouldHaveMoreUpdates {
            self.nc.postNotificationName(kReminderNoteUpdatesAvailableNotification, object: noteSetting.reminderId)
        }
    }
    
    private func notifyLoadingForReminderId(reminderId:String){
        nc.postNotificationName(kReminderNoteLoadingNotification, object: reminderId)
    }
    private func notifyLoadingFinishedForReminderId(reminderId:String){
        nc.postNotificationName(kReminderNoteLoadingFinishedNotification, object: reminderId)
    }
    private func notifyNoteUpdatesAvailableForReminderId(reminderId:String){
        nc.postNotificationName(kReminderNoteUpdatesAvailableNotification, object: reminderId)
    }
    
    func getNotesForReminder(reminderId:String) -> NSArray?{
        if let noteSetting = self.getSettingsForReminderId(reminderId) {
            return noteSetting.getNotes()
        }
        return nil
    }
    
    func loadEarlierNotesForReminderId(reminderId:String) -> Bool{
        if self.loadingSet.containsObject(reminderId) {
            return true
        }
        if let noteSetting = self.getSettingsForReminderId(reminderId) {
            self.loadingSet.addObject(reminderId)
            self.nc.postNotificationName(kReminderNoteLoadingEarlierNotification, object: reminderId)
            noteSetting.loadQuery.skip = noteSetting.loadSkip + noteSetting.loadLimit
            noteSetting.loadQuery.findObjectsInBackgroundWithBlock(self.findResultBlock(noteSetting,notificationToPostAfter:kReminderNoteLoadingEarlierFinishedNotification))
        }
        return false
    }
    
    func loadNotesForReminderId(reminderId:String) -> Bool{
        if self.loadingSet.containsObject(reminderId) {
            return true
        }
        self.notifyLoadingForReminderId(reminderId)
        if let noteSetting = self.getSettingsForReminderId(reminderId) {
            if self.hasPendingUpdates(reminderId) || !self.firstRequestAfterGoingBackground.containsObject(reminderId){
                self.loadingSet.addObject(reminderId)
                self.firstRequestAfterGoingBackground.addObject(reminderId)
                noteSetting.receiveNotesQuery.whereKey("createdAt", greaterThan: noteSetting.lastNoteCreatedAt)
                noteSetting.receiveNotesQuery.findObjectsInBackgroundWithBlock(self.findResultBlock(noteSetting,notificationToPostAfter:kReminderNoteLoadingFinishedNotification))
            }else{
                self.notifyLoadingFinishedForReminderId(noteSetting.reminderId)
            }
        }else {
            self.loadingSet.addObject(reminderId)
            self.firstRequestAfterGoingBackground.addObject(reminderId)
            var noteSetting = ReminderNoteSetting(reminderId: reminderId)
            noteSetting.loadQuery.findObjectsInBackgroundWithBlock(self.findResultBlock(noteSetting,notificationToPostAfter:kReminderNoteLoadingFinishedNotification))
        }
        return false
    }
    
    func isReminderLoading(reminderId:String) -> Bool {
        return self.loadingSet.containsObject(reminderId)
    }
    
    func trySendingAgain(note:ReminderNote){
        note.deliveryStatus = DeliveryStatus.Sending
        nc.postNotificationName(kReminderNoteSavingNotification, object: note.reminderId)
        note.saveInBackgroundWithBlock { (success:Bool, error:NSError!) -> Void in
            if success {
                note.deliveryStatus = DeliveryStatus.Sent
            }else {
                note.deliveryStatus = DeliveryStatus.Error
            }
            self.nc.postNotificationName(kReminderNoteSaveFinishedNotification, object: note.reminderId)
        }
    }
    
    func addNote(text:String,forReminderId reminderId:String){
        var reminderNote = ReminderNote()
        reminderNote.sender = PFUser.currentUser().username
        reminderNote.text = text
        reminderNote.reminderId = reminderId
        reminderNote.deliveryStatus = DeliveryStatus.Sending
        reminderNote.sentAt = NSDate()
        var noteSetting = self.getSettingsForReminderId(reminderId)
        noteSetting?.addNotes([reminderNote], sort: false)
        self.nc.postNotificationName(kReminderNoteSavingNotification, object: reminderId)
        reminderNote.saveInBackgroundWithBlock { (success:Bool, error:NSError!) -> Void in
            if success {
                reminderNote.deliveryStatus = DeliveryStatus.Sent
            }else {
                reminderNote.deliveryStatus = DeliveryStatus.Error
            }
            self.nc.postNotificationName(kReminderNoteSaveFinishedNotification, object: reminderId)
        }
    }
    
    func hasPendingUpdates(reminderId:String) -> Bool{
        if let reminderPendingNotifications = self.notificationPending.valueForKey(reminderId) as? NSMutableSet {
            return reminderPendingNotifications.count > 0
        }
        return false
    }
    
    func remoteNotificationReceived(command:PushCommand!, application:UIApplication, userInfo:NSDictionary!,completionHandler:(UIBackgroundFetchResult) -> Void ){
        if let reminderId = userInfo["r"] as? String {
            if let noteId = userInfo["n"] as? String {
                var isExistingNote = false
                if let noteSettings = self.getSettingsForReminderId(reminderId){
                    isExistingNote = noteSettings.isExistingNote(noteId)
                }
                if !isExistingNote {
                    if let reminderPendingNotifications = self.notificationPending.valueForKey(reminderId) as? NSMutableSet {
                        reminderPendingNotifications.addObject(noteId)
                    }else {
                        self.notificationPending.setObject(NSMutableSet(object: noteId), forKey: reminderId)
                    }
                }
                self.notifyNoteUpdatesAvailableForReminderId(reminderId)
                if application.applicationState == UIApplicationState.Active {
                    let rootNVC = application.keyWindow?.rootViewController as UINavigationController
                    let topVC = rootNVC.topViewController
                    if topVC is NotesViewController {
                        let nVC = topVC as NotesViewController
                        if nVC.reminderId == reminderId {
                            //already looking at it
                            completionHandler(UIBackgroundFetchResult.NoData)
                            return
                        }
                    }
                    if let username = userInfo["u"] as? String{
                        if let text = userInfo["t"] as? String {
                            var contact = ContactsManager.sharedInstance.getUDContactForUserId(username)
                            JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
                            TSMessage.showNotificationWithTitle("\(contact.name()): \(text)", type: TSMessageNotificationType.Message, duration: 0, callback: { () -> Void in
                                self.nc.postNotificationName(kReminderShowNotification, object: reminderId)
                            })
                        }
                    }
                }
            }
        }
        completionHandler(UIBackgroundFetchResult.NoData)
    }
    
    func applicationWillEnterForeground() {
        self.firstRequestAfterGoingBackground.removeAllObjects()
    }
}
