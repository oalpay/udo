//
//  NotesViewController.swift
//  udo
//
//  Created by Osman Alpay on 27/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class NotesViewController:JSQMessagesViewController, UIActionSheetDelegate{
    var notes:NSArray!
    var reminderId:String!
    var outgoingBubbleImageData:JSQMessagesBubbleImage!
    var incomingBubbleImageData:JSQMessagesBubbleImage!
    
    var contactsManager = ContactsManager.sharedInstance
    var reminderManager = ReminderManager.sharedInstance
    
    var nc = NSNotificationCenter.defaultCenter()
    
    let calendar = NSCalendar.currentCalendar()
    let unitFlags = NSCalendarUnit.YearCalendarUnit | NSCalendarUnit.MonthCalendarUnit | NSCalendarUnit.DayCalendarUnit | NSCalendarUnit.HourCalendarUnit | NSCalendarUnit.MinuteCalendarUnit
    
    var actionSheetForIndexPath:NSIndexPath!
    
    var sendButton:UIButton!
    
    var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputToolbar.contentView.leftBarButtonItem = nil
        self.inputToolbar.contentView.textView.placeHolder = "Message"
        self.inputToolbar.contentView.rightBarButtonItem.setTitleColor(AppTheme.tintColor, forState: UIControlState.Normal)
        self.inputToolbar.contentView.rightBarButtonItem.setTitleColor(AppTheme.tintColor, forState: UIControlState.Highlighted)
        
        self.senderId = PFUser.currentUser().username
        self.senderDisplayName = self.contactsManager.getUDContactForUserId(self.senderId).name()
        
        var bubbleFactory = JSQMessagesBubbleImageFactory()
        self.outgoingBubbleImageData = bubbleFactory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
        self.incomingBubbleImageData = bubbleFactory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleGreenColor())
        
        var reminderNotes = self.reminderManager.getReminderNotes(self.reminderId)
        self.notes = reminderNotes.getNotes()
        if reminderNotes.canHaveEarlierNotes() {
            self.showLoadEarlierMessagesHeader = true
        }else {
            self.showLoadEarlierMessagesHeader = false
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.nc.addObserver(self, selector: "noteActivityNotification:", name: kNoteActivityNotification, object: nil)
        self.nc.addObserver(self, selector: "reminderManagerActivityNotification:", name: kReminderManagerActivityNotification, object: nil)
        
        self.updateActivity()

    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.nc.removeObserver(self)
        self.reminderManager.setNotesAsSeenForReminder(self.reminderId)
    }
    
    func updateActivity(){
        if self.reminderManager.getReminderNotes(self.reminderId).loadingEarlier || self.reminderManager.isSyncing {
            self.showActivity()
        }else {
            self.hideActivity()
        }
    }
    
    func showActivity(){
        self.activityIndicator.startAnimating()
        self.navigationItem.titleView = activityIndicator
        self.showLoadEarlierMessagesHeader = false
    }
    func hideActivity(){
        self.activityIndicator.stopAnimating()
        self.navigationItem.titleView = nil
    }
    
    func reminderManagerActivityNotification(notification:NSNotification){
        if let activity = notification.object as? ReminderManagerActivityNotification {
            switch activity.activity {
            case .SyncStarted:
                 self.showActivity()
            case .SyncEnded:
                self.hideActivity()
                self.refreshFromNotesManager()
            default:
                break
            }
        }
    }
    
    func noteActivityNotification(notification:NSNotification){
        if let activity = notification.object as? NoteActivityNotification {
            if self.reminderId == activity.reminderId {
                switch activity.activity {
                case .LoadingEarlierStarted:
                    self.updateActivity()
                case .LoadingEarlierEnded:
                    self.updateActivity()
                    let reminderNotes = self.reminderManager.getReminderNotes(self.reminderId)
                    self.notes = reminderNotes.getNotes()
                    self.collectionView.reloadData()
                    self.showLoadEarlierMessagesHeader = reminderNotes.canHaveEarlierNotes()
                case .LoadingStarted:
                    self.showTypingIndicator = true
                case .LoadingEnded:
                    self.refreshFromNotesManager()
                case .Saving:
                    self.notes = self.reminderManager.getReminderNotes(self.reminderId).getNotes()
                    self.finishSendingMessage()
                case .Saved:
                    JSQSystemSoundPlayer.jsq_playMessageSentSound()
                    self.collectionView.reloadData()
                default:
                    break
                }
            }
        }
    }
    
    func refreshFromNotesManager(){
        var oldCount = self.notes.count
        let reminderNotes = self.reminderManager.getReminderNotes(self.reminderId)
        self.notes = reminderNotes.getNotes()
        self.finishReceivingMessage()
        if oldCount < self.notes.count {
            JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
        }
        if reminderNotes.canHaveEarlierNotes() {
            self.showLoadEarlierMessagesHeader = true
        }else {
            self.showLoadEarlierMessagesHeader = false
        }

    }
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
        self.reminderManager.sendNoteText(text, forReminderId: self.reminderId)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        return notes.objectAtIndex(indexPath.item) as JSQMessageData
    }
    
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        var note = self.notes.objectAtIndex(indexPath.item) as Note
        if note.sender == PFUser.currentUser().username {
            return self.outgoingBubbleImageData
        }
        return self.incomingBubbleImageData
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        let note = self.notes.objectAtIndex(indexPath.item) as Note
        let contact =  self.contactsManager.getUDContactForUserId(note.sender)
        return UDAvatarImageDataSource(contact: contact)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        let currentNote = self.notes.objectAtIndex(indexPath.item) as Note
        if  indexPath.item % 10 == 0 {
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(currentNote.date())
        }
        var previousNoteIndex = indexPath.item - 1
        if previousNoteIndex >= 0 {
            let pNote = self.notes.objectAtIndex(previousNoteIndex) as Note
            var pDate = pNote.date()
            var pComponents = calendar.components(unitFlags, fromDate: pDate)
            
            var cDate = currentNote.date()
            var cComponents = calendar.components(unitFlags, fromDate: cDate)
            if cComponents.year == pComponents.year && cComponents.month == pComponents.month && cComponents.day == pComponents.day {
                return nil
            }
        }
        return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(currentNote.date())
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        var note = self.notes.objectAtIndex(indexPath.item) as Note
        
        if note.sender == PFUser.currentUser().username {
            return nil
        }
        
        if indexPath.item - 1 > 0 {
            var previousNote = self.notes.objectAtIndex(indexPath.item - 1) as Note
            if (previousNote.sender == note.sender) {
                return nil
            }
        }
        
        return NSAttributedString(string: note.senderDisplayName())
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.notes.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        var cell = super.collectionView(collectionView, cellForItemAtIndexPath:indexPath) as JSQMessagesCollectionViewCell
        cell.avatarImageView.layer.cornerRadius =  CGFloat(kJSQMessagesCollectionViewAvatarSizeDefault / 2)
        cell.avatarImageView.layer.masksToBounds = true
        //cell.avatarImageView.layer.borderWidth = 1
        //cell.avatarImageView.layer.borderColor = UIColor.grayColor().CGColor
        cell.backgroundColor = UIColor.clearColor()
        cell.cellBottomLabel.textColor = UIColor.darkGrayColor()
        cell.cellTopLabel.textColor = UIColor.darkGrayColor()
        cell.messageBubbleTopLabel.textColor = UIColor.darkGrayColor()
        
        
        var note = self.notes.objectAtIndex(indexPath.item) as Note
        if (note.sender == PFUser.currentUser().username ) {
            cell.textView.textColor = UIColor.blackColor()
        }
        else {
            cell.textView.textColor = UIColor.whiteColor()
        }
        cell.textView.linkTextAttributes = [ NSForegroundColorAttributeName : cell.textView.textColor,
            NSUnderlineStyleAttributeName : NSUnderlineStyle.StyleSingle.rawValue ]
        return cell;
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        var topLabelText = self.collectionView(collectionView, attributedTextForCellTopLabelAtIndexPath: indexPath)
        if topLabelText != nil {
            return kJSQMessagesCollectionViewCellLabelHeightDefault;
        }
        return 0.0
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        /**
        *  iOS7-style sender name labels
        */
        var note = self.notes.objectAtIndex(indexPath.item) as Note
        if note.sender == PFUser.currentUser().username {
            return 0.0
        }
        
        if (indexPath.item - 1 > 0) {
            var previousNote = self.notes.objectAtIndex(indexPath.item - 1) as Note
            if (previousNote.sender == note.sender) {
                return 0.0
            }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        return 15
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        let note = self.notes.objectAtIndex(indexPath.item) as Note
        if let status = note.deliveryStatus {
            if status == DeliveryStatus.Error {
                return NSAttributedString(string:"Send failed")
            }else if status == DeliveryStatus.Sending {
                return NSAttributedString(string:"Sending...")
            }
        }
        return  NSAttributedString(string: JSQMessagesTimestampFormatter.sharedFormatter().timeForDate(note.date()))
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 0 {
            let note = self.notes.objectAtIndex(self.actionSheetForIndexPath.item) as Note
            self.reminderManager.trySendingNoteAgain(note)
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapCellAtIndexPath indexPath: NSIndexPath!, touchLocation: CGPoint) {
    }
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapAvatarImageView avatarImageView: UIImageView!, atIndexPath indexPath: NSIndexPath!) {
        
    }
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAtIndexPath indexPath: NSIndexPath!) {
        let note = self.notes.objectAtIndex(indexPath.item) as Note
        if let status = note.deliveryStatus {
            if status == DeliveryStatus.Error {
                let actionSheet = UIActionSheet()
                actionSheet.delegate = self
                actionSheet.addButtonWithTitle("Send again")
                actionSheet.cancelButtonIndex =  actionSheet.addButtonWithTitle("Cancel")
                actionSheet.showInView(self.collectionView)
                self.actionSheetForIndexPath = indexPath
            }
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, header headerView: JSQMessagesLoadEarlierHeaderView!, didTapLoadEarlierMessagesButton sender: UIButton!) {
        self.reminderManager.loadEarlierNotesForReminder(self.reminderId)
    }
}


class UDAvatarImageDataSource :NSObject, JSQMessageAvatarImageDataSource{
    var contact:UDContact!
    
    init(contact:UDContact){
        super.init()
        self.contact = contact
    }
    
    func avatarImage() -> UIImage! {
        if let image = self.contact.cachedPublicImage(){
            return image
        }
        return contact.contactImage()
    }
    
    func avatarHighlightedImage() -> UIImage! {
        if let image = self.contact.cachedPublicImage(){
            return image
        }
        return contact.contactImage()
    }
    
    func avatarPlaceholderImage() -> UIImage! {
        if let image = self.contact.cachedPublicImage(){
            return image
        }
        return contact.contactImage()
    }
}
