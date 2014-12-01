//
//  NotesManager.swift
//  udo
//
//  Created by Osman Alpay on 27/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

let kNoteActivityNotification = "kNoteActivityNotification"

enum NoteActivity {
    case LoadingEarlierStarted
    case LoadingEarlierEnded
    case LoadingStarted
    case LoadingEnded
    case Saving
    case Saved
}

class NoteActivityNotification {
    let reminderId:String
    let activity:NoteActivity
    init(reminderId:String, activity:NoteActivity){
        self.reminderId = reminderId
        self.activity = activity
    }
}

var kNotesLastRead = "NotesLastRead"

class ReminderNotes {
    var reminderId:String!
    private var pendingNoteIds:NSMutableSet!
    private var notesArray:NSMutableArray!
    private var notesSet:NSMutableSet!
    private var lastLoaded:NSDate!
    var limit = 100
    
    var loadingEarlier = false
    var loading = false
    private var error = false
    private var haveEarlierNotes = true
    private var lastSeen:NSDate!
    
    init(reminderId:String) {
        self.reminderId = reminderId
        self.notesArray = NSMutableArray()
        self.notesSet = NSMutableSet()
        self.pendingNoteIds  = NSMutableSet()
    }
    
    func resetWithNotes(notesDescending notes:NSArray){
        self.notesArray.removeAllObjects()
        self.notesSet.removeAllObjects()
        self.appendNotes(notesDescending: notes)
    }
    
    func setCanHaveEarlierNotes(haveEarlierNotes:Bool){
        self.haveEarlierNotes = haveEarlierNotes
    }
    
    func canHaveEarlierNotes() -> Bool {
        return self.haveEarlierNotes
    }
    
    func setError(error:Bool){
        self.error = error
    }
    
    func hasError() -> Bool {
        return self.error
    }
    
    func addPendingNote(noteId:String){
        if !self.notesSet.containsObject(noteId){
            self.pendingNoteIds.addObject(noteId)
        }
    }
    
    func removePendingNote(noteId:String){
        self.pendingNoteIds.removeObject(noteId)
    }
    
    func hasPendingNotes() -> Bool {
        return self.pendingNoteIds.count != 0
    }
    
    func removeAllPendingNotes() {
        self.pendingNoteIds.removeAllObjects()
    }
    
    func appendNotes(notesDescending notes:NSArray){
        for (var index = notes.count - 1; index >= 0; index--){
            self.appendNote(notes.objectAtIndex(index) as Note)
        }
    }
    
    func prependNote(note:Note){
        if self.notesSet.containsObject(note.objectId){
            return
        }
        self.pendingNoteIds.removeObject(note.objectId)
        self.notesSet.addObject(note.objectId)
        self.notesArray.insertObject(note, atIndex: 0)
    }
    
    func appendNote(note:Note){
        if self.notesSet.containsObject(note.objectId){
            return
        }
        self.notesSet.addObject(note.objectId)
        self.notesArray.addObject(note)
        self.pendingNoteIds.removeObject(note.objectId)
        
    }
    
    func appendMyNote(note:Note){
        self.notesArray.addObject(note)
    }
    
    func prependNotes(notesDescending notes:NSArray){
        for note in notes as [Note] {
            self.prependNote(note)
        }
    }
    
    func loadQuery() -> PFQuery {
        var query = Note.query()
        query.whereKey("reminderId",equalTo:self.reminderId)
        query.limit = limit
        query.orderByDescending("createdAt")
        query.whereKey("sender", notEqualTo: PFUser.currentUser().username)
        if let lastReceivedNoteDate = self.getLastReceivedNoteDate() {
            query.whereKey("createdAt", greaterThan: lastReceivedNoteDate)
        }
        return query
    }
    
    func loadEarlierQuery() -> PFQuery {
        var query = Note.query()
        query.whereKey("reminderId",equalTo:reminderId)
        query.limit = self.limit
        query.orderByDescending("createdAt")
        if let oldestNoteDate = self.getOldestReceivedNoteDate() {
            query.whereKey("createdAt", lessThan: oldestNoteDate)
        }
        return query
    }
    
    func getOldestReceivedNoteDate() -> NSDate? {
        for oldestNote in self.notesArray.copy() as [Note] {
            if oldestNote.createdAt != nil {
                return oldestNote.createdAt
            }
        }
        return nil
    }
    
    func getLastNote() -> Note? {
        return self.notesArray.lastObject as? Note
    }
    
    func getLastReceivedNote() -> Note? {
        for (var index = self.notesArray.count - 1; index >= 0; index--) {
            let note = self.notesArray.objectAtIndex(index) as Note
            if note.createdAt != nil {
                return note
            }
        }
        return nil
    }
    
    func getLastReceivedNoteDate() -> NSDate? {
        return (self.getLastReceivedNote())?.createdAt
    }
    
    func getNotes() -> NSArray{
        return self.notesArray.copy() as NSArray
    }
    
    func isExistingNote(noteId:String) -> Bool{
        return self.notesSet.containsObject(noteId)
    }
    
    func setLastSeen(lastSeen:NSDate!){
        self.lastSeen = lastSeen
    }
    
    func getUnreadMessageCount() -> Int {
        var count = 0
        if self.lastSeen == nil {
            count = self.notesArray.count
        }else {
            let range = NSMakeRange(0, self.notesArray.count)
            var index = self.notesArray.indexOfObject(self.lastSeen, inSortedRange: range, options: NSBinarySearchingOptions.LastEqual, usingComparator: { (o, d) -> NSComparisonResult in
                let note = o as Note
                return note.date().compare(d as NSDate)
            })
            if index != NSNotFound {
                 // dont count the notes sent by me
                var me = PFUser.currentUser().username
                for ( index++; index < self.notesArray.count; index++){
                    let note = self.notesArray.objectAtIndex(index) as Note
                    if note.sender != me{
                        count += 1
                    }
                }
            }
        }
        return count + self.pendingNoteIds.count
    }
}

class NotesManager {
    private var reminderNotes = NSMutableDictionary()
    private var nc = NSNotificationCenter.defaultCenter()
    
    private var userDefaults = NSUserDefaults.standardUserDefaults()
    private var notesLastRead:NSMutableDictionary!
    
    init() {
        var userNoteLastRead = self.userDefaults.objectForKey(kNotesLastRead) as? NSDictionary
        if userNoteLastRead != nil {
            self.notesLastRead = userNoteLastRead!.mutableCopy() as NSMutableDictionary
        }else {
            self.notesLastRead = NSMutableDictionary()
        }
    }
    
    func reminderDeleted(reminderId:String){
        self.notesLastRead.removeObjectForKey(reminderId)
        self.userDefaults.setObject(self.notesLastRead, forKey: kNotesLastRead)
        self.reminderNotes.removeObjectForKey(reminderId)
    }
    
    func setReminderNotesAsSeen(reminderId:String){
        let reminderNotes = self.getReminderNotes(reminderId)
        if let  date = reminderNotes.getLastReceivedNoteDate(){
            reminderNotes.setLastSeen(date)
            self.notesLastRead.setObject(date, forKey: reminderId)
            self.userDefaults.setObject(self.notesLastRead, forKey: kNotesLastRead)
        }
    }
    
    func getReminderNotes(reminderId:String) -> ReminderNotes {
        if let reminderNotes = self.reminderNotes.objectForKey(reminderId) as? ReminderNotes{
            return reminderNotes
        }
        let reminderNotes = ReminderNotes(reminderId: reminderId)
        reminderNotes.setLastSeen(self.notesLastRead.objectForKey(reminderId) as? NSDate)
        self.reminderNotes.setObject(reminderNotes, forKey: reminderId)
        return reminderNotes
    }
    
    private func postNoteActivityNotification(activity:NoteActivity, reminderId:String) {
        let activity = NoteActivityNotification(reminderId: reminderId, activity: activity)
        nc.postNotificationName(kNoteActivityNotification, object: activity)
    }
    
    private func notifyLoadingForReminderId(reminderId:String){
        self.postNoteActivityNotification(NoteActivity.LoadingStarted, reminderId: reminderId)
    }
    private func notifyLoadingFinishedForReminderId(reminderId:String){
        self.postNoteActivityNotification(NoteActivity.LoadingEnded, reminderId: reminderId)
    }
    private func notifyLoadingEarliarForReminderId(reminderId:String){
        self.postNoteActivityNotification(NoteActivity.LoadingEarlierStarted, reminderId: reminderId)
    }
    private func notifyLoadingEarliarFinishedForReminderId(reminderId:String){
        self.postNoteActivityNotification(NoteActivity.LoadingEarlierEnded, reminderId: reminderId)
    }
    
    func remoteReminderNoteNotificationReceived(pushInfo:PushNotificationUserInfo) {
        self.getReminderNotes(pushInfo.reminderId).addPendingNote(pushInfo.noteId)
    }
    
    func getLastNoteCreatedAtForReminders() -> NSDictionary {
        var dates = NSMutableDictionary()
        for reminderNote in self.reminderNotes.allValues as [ReminderNotes] {
            if let lastReceivedDate =  reminderNote.getLastReceivedNoteDate() {
                dates.setObject(lastReceivedDate, forKey: reminderNote.reminderId)
            }
        }
        return dates
    }
    
    func syncUserWith(response:NSDictionary) -> NSMutableSet {
        var changedNotesSet = NSMutableSet()
        for reminderId in response.allKeys as [String]{
            let updates = response.objectForKey(reminderId) as NSDictionary
            let notes = updates.objectForKey("n") as NSArray
            let isSliced = updates.objectForKey("s") as Bool
            var reminderNotes = self.getReminderNotes(reminderId)
            reminderNotes.setCanHaveEarlierNotes(isSliced)
            if isSliced {
                reminderNotes.resetWithNotes(notesDescending: notes)
            }else{
                reminderNotes.appendNotes(notesDescending: notes)
            }
            if reminderNotes.hasPendingNotes(){
                self.loadNotes(reminderNotes.reminderId, tryCount: 0)
            }
            if notes.count > 0 {
                changedNotesSet.addObject(reminderId)
            }
        }
        return changedNotesSet
    }
    
    func loadNotes(reminderId:String,tryCount:Int) {
        var noteSetting = self.getReminderNotes(reminderId)
        if noteSetting.loading || tryCount > 3 {
            return
        }
        self.notifyLoadingForReminderId(reminderId)
        noteSetting.loading = true
        noteSetting.loadQuery().findObjectsInBackgroundWithBlock({ (notes:[AnyObject]!, error:NSError!) -> Void in
            if error != nil {
                noteSetting.setError(true)
                TSMessage.showNotificationWithTitle("Connection problem", type: TSMessageNotificationType.Error)
            }else {
                noteSetting.appendNotes(notesDescending: notes)
                if notes.count >= noteSetting.limit {
                    noteSetting.setCanHaveEarlierNotes(true)
                }
            }
            noteSetting.loading = false
            self.notifyLoadingFinishedForReminderId(noteSetting.reminderId)
            if noteSetting.hasPendingNotes() {
                self.loadNotes(reminderId,tryCount: tryCount + 1)
            }
        })
    }
    
    func loadEarlierNotesForReminderId(reminderId:String){
        var noteSetting = self.getReminderNotes(reminderId)
        if noteSetting.loadingEarlier {
            return
        }
        self.notifyLoadingEarliarForReminderId(reminderId)
        noteSetting.loadingEarlier = true
        noteSetting.loadEarlierQuery().findObjectsInBackgroundWithBlock({ (notes:[AnyObject]!, error:NSError!) -> Void in
            if error != nil {
                noteSetting.setError(true)
                TSMessage.showNotificationWithTitle("Connection problem", type: TSMessageNotificationType.Error)
            }else {
                noteSetting.prependNotes(notesDescending: notes)
                if notes.count >= noteSetting.limit {
                    noteSetting.setCanHaveEarlierNotes(true)
                }else {
                    noteSetting.setCanHaveEarlierNotes(false)
                }
            }
            noteSetting.loadingEarlier = false
            self.notifyLoadingEarliarFinishedForReminderId(reminderId)
        })
    }
    
    func trySendingAgain(note:Note){
        note.deliveryStatus = DeliveryStatus.Sending
        self.postNoteActivityNotification(NoteActivity.Saving, reminderId: note.reminderId)
        note.saveInBackgroundWithBlock { (success:Bool, error:NSError!) -> Void in
            if success {
                note.deliveryStatus = DeliveryStatus.Sent
            }else {
                note.deliveryStatus = DeliveryStatus.Error
            }
            self.postNoteActivityNotification(NoteActivity.Saved, reminderId: note.reminderId)
        }
    }
    
    func addNote(text:String,forReminderId reminderId:String){
        var reminderNote = Note()
        reminderNote.sender = PFUser.currentUser().username
        reminderNote.text = text
        reminderNote.reminderId = reminderId
        reminderNote.deliveryStatus = DeliveryStatus.Sending
        reminderNote.sentAt = NSDate()
        var noteSetting = self.getReminderNotes(reminderId)
        noteSetting.appendMyNote(reminderNote)
        self.postNoteActivityNotification(NoteActivity.Saving, reminderId: reminderId)
        reminderNote.saveInBackgroundWithBlock { (success:Bool, error:NSError!) -> Void in
            if success {
                reminderNote.deliveryStatus = DeliveryStatus.Sent
            }else {
                reminderNote.deliveryStatus = DeliveryStatus.Error
            }
            self.postNoteActivityNotification(NoteActivity.Saved, reminderId: reminderId)
        }
    }
    
    
    func showAlertForPushNotification(pushInfo:PushNotificationUserInfo) {
        let rootNVC = UIApplication.sharedApplication().keyWindow?.rootViewController as UINavigationController
        let topVC = rootNVC.topViewController
        if topVC is NotesViewController {
            let nVC = topVC as NotesViewController
            if nVC.reminderId == pushInfo.reminderId {
                //already looking at it
                return
            }
        }
        var senderName = ContactsManager.sharedInstance.getUDContactForUserId(pushInfo.senderId).name()
        JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
        TSMessage.showNotificationWithTitle("\(senderName): \(pushInfo.noteTitle)", type: TSMessageNotificationType.Message, duration: 0, callback: { () -> Void in
            self.nc.postNotificationName(kReminderShowNotification, object:  pushInfo.reminderId)
        })
    }
    
    
    func applicationWillEnterForeground() {
        
    }
}
