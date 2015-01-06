//
//  TaskEditViewController.swift
//  udo
//
//  Created by Osman Alpay on 06/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import MessageUI

class ReminderViewController: StaticDataTableViewController,UITextViewDelegate,CollabaratorViewDelegate,UIActionSheetDelegate, MFMessageComposeViewControllerDelegate{
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    @IBOutlet weak var collaboratorsView: CollabaratorView!
    
    @IBOutlet weak var taskTextView: UITextView!
    
    
    @IBOutlet weak var addNewNoteLabel: UILabel!
    @IBOutlet weak var notesLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var notesImageView: UDContactImageView!
    @IBOutlet weak var notesLabel: UILabel!
    @IBOutlet weak var notesDateLabel: UILabel!
    @IBOutlet weak var badgeLabel: UDBadgeLabel!
    @IBOutlet weak var notesCell: UITableViewCell!
    
    @IBOutlet weak var dueDateSwitch: UISwitch!
    @IBOutlet weak var dueDateSwitchCell: UITableViewCell!
    @IBOutlet weak var calendarIconImageView: UIImageView!
    @IBOutlet weak var dueDateLabel: UILabel!
    @IBOutlet weak var dueDateCell: UITableViewCell!
    var dueDatePicker: UIDatePicker!
    @IBOutlet weak var dueDatePickerCell: UITableViewCell!
    @IBOutlet weak var dueDateRepeatLabel: UILabel!
    @IBOutlet weak var dueDateRepeatCell: UITableViewCell!
    
    @IBOutlet weak var addToMyRemindersSwitch: UISwitch!
    @IBOutlet weak var remindMeOnADaySwitch: UISwitch!
    @IBOutlet weak var remindMeOnADayCell: UITableViewCell!
    @IBOutlet weak var notificationIconImageView: UIImageView!
    @IBOutlet weak var remindMeAlarmDateLabel: UILabel!
    @IBOutlet weak var remindMeAlarmDateCell: UITableViewCell!
    var remindMeDatePicker: UIDatePicker!
    @IBOutlet weak var remindMeDatePickerCell: UITableViewCell!
    @IBOutlet weak var remindMeRepeatLabel: UILabel!
    @IBOutlet weak var remindMeRepeatCell: UITableViewCell!
    
    private var createdAtLabel:UILabel!
    
    private let dateFormatter = NSDateFormatter()
    private let contactsManager = ContactsManager.sharedInstance
    private let reminderManager = ReminderManager.sharedInstance
    var reminderKey:String!
    private var reminder: Reminder!
    private var collaborators:[String] = []
    private var actionSheetOpertaion = Dictionary<Int,()->Void>()
    private var sendInvitationToNumber:String!
    
    private var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
    
    private var selectedDueDate:NSDate!
    private var selectedDuaDateRepeatInterval:NSCalendarUnit!
    private var selectedAlarmDate:NSDate!
    private var selectedAlarmDateRepeatInterval:NSCalendarUnit!
    
    private var nc = NSNotificationCenter.defaultCenter()
    private var userDefaults = NSUserDefaults.standardUserDefaults()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UITapGestureRecognizer(target: self, action:"touchOutside:")
        tap.cancelsTouchesInView = false
        self.tableView.addGestureRecognizer(tap)
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
        
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        
        //self.addToMyRemindersSwitch.onTintColor = AppTheme.doneColor
        //self.remindMeOnADaySwitch.onTintColor = AppTheme.doneColor
        
        //empty means not set yet
        self.remindMeAlarmDateLabel.text = ""
        
        self.collaboratorsView.collabaratorDelegate = self
        
        self.hideSectionsWithHiddenRows = true
        self.insertTableViewRowAnimation = UITableViewRowAnimation.Top
        self.deleteTableViewRowAnimation = UITableViewRowAnimation.Automatic
        
        var calendarImage = UIImage(named: "calendar32")?.imageTintedWithColor(AppTheme.iconMaskColor)
        self.calendarIconImageView.image = calendarImage
        var notificationImage = UIImage(named: "notifications32")?.imageTintedWithColor(AppTheme.iconMaskColor)
        self.notificationIconImageView.image = notificationImage
        
        
        self.notesImageView.layer.cornerRadius = self.notesImageView.frame.size.height / 2
        self.notesImageView.layer.masksToBounds = true

        self.badgeLabel.text = "0"
        
        self.createdAtLabel = UILabel(frame: CGRect(x: 15, y: -20, width: 300, height: 20))
        self.tableView.addSubview(createdAtLabel)
        self.createdAtLabel.font = UIFont.systemFontOfSize(17)
        self.createdAtLabel.textColor = UIColor.darkGrayColor()
        self.createdAtLabel.text = ""
        
        self.addListeners()
        
        self.tableView.contentInset = UIEdgeInsets(top: -15, left: 0, bottom: 0, right: 0)
        
        self.prepareReminder()
        self.updateAllFields()
        if reminder.objectId == nil {
            self.taskTextView.becomeFirstResponder()
        }
    }
    
    func addListeners(){
        self.nc.addObserver(self, selector: "remindersChangedNotification:", name: kRemindersChangedNotification, object: nil)
        self.nc.addObserver(self, selector: "reminderActivityNotification:", name: kReminderActivityNotification, object: nil)
        self.nc.addObserver(self, selector: "reminderManagerActivityNotification:", name: kReminderManagerActivityNotification, object: nil)
        
        self.nc.addObserver(self, selector: "contactsChanged:", name: kContactsChangedNotification, object: nil)
        self.nc.addObserver(self, selector: "noteActivityNotification:", name: kNoteActivityNotification, object: nil)
    }
    
    func removeListeners(){
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func didMoveToParentViewController(parent: UIViewController?) {
        if parent == nil {
            self.removeListeners()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        self.updateNavigationItemButtons()
        self.updateNotes()
    }
    
    override func viewDidAppear(animated: Bool) {
        if self.sendInvitationToNumber != nil {
            self.sendInvitation(sendInvitationToNumber)
            self.sendInvitationToNumber = nil
        }
    }
    
    func contactsChanged(notification:NSNotification) {
        self.collaboratorsView.refresh()
    }
    
    func remindersChangedNotification(notification:NSNotification){
        if let change = notification.object as? RemindersChangedNotification {
            if change.hasKeyInUpdateSet(self.reminderKey) {
                self.prepareReminder()
                if change.isLocalChange {
                    self.updateRemindMeFields()
                }else {
                    self.updateDueDateFields()
                    self.updateCollaborators()
                    self.updateTitle()
                }
                self.reloadDataAnimated(true)
            }
        }
    }
    func reminderActivityNotification(notification:NSNotification){
        if let activity = notification.object as? ReminderActivityNotification {
            if activity.reminderId == self.reminderKey {
                switch activity.activity {
                case .Loading,.Saving:
                    self.updateActivity()
                case .Loaded,.Saved:
                    self.prepareReminder()
                    self.updateAllFields()
                case .Created:
                    self.reminderKey = activity.idAfterCreate
                default:
                    break
                }
            }
        }
    }
    
    func reminderManagerActivityNotification(notification:NSNotification){
        if let activity = notification.object as? ReminderManagerActivityNotification {
            switch activity.activity {
            case .SyncEnded,.LoadingRemindersEnded:
                self.updateNotes()
            default:
                self.updateActivity()
            }
        }
    }
    
    func noteActivityNotification(notification:NSNotification){
        if let activity = notification.object as? NoteActivityNotification {
            if activity.reminderId == self.reminderKey {
                switch activity.activity {
                case .LoadingEnded,.Saved:
                    self.notesLoadingIndicator.stopAnimating()
                    self.updateLastNote()
                default:
                    break
                }
            }
        }
    }
    
    // not used !!
    func showNoteLoading(){
        self.notesLoadingIndicator.startAnimating()
        self.addNewNoteLabel.hidden = true
        self.notesImageView.hidden = true
        self.notesLabel.hidden = true
        self.badgeLabel.hidden = true
        self.notesDateLabel.hidden = true
    }
    
    func updateLastNote(){
        var isNotesEmpty = true
        if let reminderNotes =  self.reminderManager.getReminderNotes(self.reminderKey){
            if let lastNote = reminderNotes.getLastNote() {
                var contact = self.contactsManager.getUDContactForUserId(lastNote.sender)
                self.notesImageView.loadWithContact(contact, showIndicator: false)
                self.notesLabel.text = "\(contact.name()): \(lastNote.text)"
                self.notesDateLabel.text = JSQMessagesTimestampFormatter.sharedFormatter().timestampForDate(lastNote.date())
                var count = reminderNotes.getUnreadMessageCount()
                self.badgeLabel.text = "\(count)"
                isNotesEmpty = false
            }
        }
        self.addNewNoteLabel.hidden = !isNotesEmpty
        self.notesImageView.hidden = isNotesEmpty
        self.notesLabel.hidden = isNotesEmpty
        self.notesDateLabel.hidden = isNotesEmpty
        self.badgeLabel.hidden = isNotesEmpty
        if self.badgeLabel.text == "0" {
            self.badgeLabel.hidden = true
        }
    }
    
    
    func isCollaboratorsDirty() -> Bool {
        var newCollaborators = NSSet(array: self.collaborators)
        var currentCollaborators  = NSSet(array: self.reminder.collaborators)
        return !newCollaborators.isEqualToSet(currentCollaborators)
    }
    
    func isTitleDirty() -> Bool {
        if self.reminder.title != self.taskTextView.text {
            return true
        }
        return false
    }
    
    func isDueDateDirty() -> Bool {
        if self.dueDateSwitch.on {
            if (reminder.dueDate == nil || ( self.reminder.dueDate != nil && !self.reminder.dueDate.isEqualToDate(self.selectedDueDate))) {
                return true
            }
        }else if reminder.dueDate != nil {
            return true
        }
        return false
    }
    func isDueDateIntervalDirty() -> Bool {
        if (self.reminder.dueDateInterval == nil && self.selectedDuaDateRepeatInterval != nil) || (self.reminder.dueDateInterval != nil && self.selectedDuaDateRepeatInterval == nil) || (self.reminder.dueDateInterval != nil && self.selectedAlarmDateRepeatInterval != nil && !self.reminder.dueDateInterval.isEqual(self.selectedAlarmDateRepeatInterval.rawValue)) {
            return true
        }
        return false
    }
    
    func isAddToMyRemindersDirty() -> Bool {
        return self.addToMyRemindersSwitch.on != self.reminder.isOnReminders
    }
    
    func isAlarmDateDirty() -> Bool {
        if self.remindMeOnADaySwitch.on {
            if (self.reminder.alarmDate == nil || ( self.reminder.alarmDate != nil && self.selectedAlarmDate != nil && !self.reminder.alarmDate.isEqualToDate(self.selectedAlarmDate))) {
                return true
            }
        }else if reminder.alarmDate != nil {
            return true
        }
        return false
    }
    
    func cancelButtonPresses(sender:AnyObject){
        self.performSegueWithIdentifier("BackToMain", sender: nil)
    }
    
    func updateNavigationItemButtons(){
        let taskText = self.taskTextView.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if ( taskText != "" &&  !self.reminder.isPlaceHolder && (self.isDirty() || self.reminder.isDirty())){
            self.navigationItem.rightBarButtonItem?.enabled = true
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.Plain, target: self, action: "cancelButtonPresses:")
        }else {
            self.navigationItem.rightBarButtonItem?.enabled = false
            self.navigationItem.leftBarButtonItem = nil
        }
    }
    
    
    func isDirty() -> Bool {
        let dirty =  self.isCollaboratorsDirty() || self.isTitleDirty() || self.isDueDateDirty() || self.isDueDateIntervalDirty() || self.isAddToMyRemindersDirty() || self.isAlarmDateDirty()
        return dirty
    }
    
    func prepareReminder(){
        if self.reminderKey == nil {
            self.reminder = Reminder()
            self.reminder.title = ""
            self.reminder.collaborators = [PFUser.currentUser().username]
            self.reminderKey = self.reminder.key()
        }else {
            self.reminder = self.reminderManager.getReminder(self.reminderKey)
            self.reminderManager.setReminderAsSeen(self.reminderKey)
        }
    }
    
    func updateAllWithoutDatePickersFields(){
        self.updateCollaborators()
        self.updateTitle()
        self.updateActivity()
        self.reloadDataAnimated(false)
    }
    
    func updateAllFields(){
        self.updateNotes()
        self.updateDueDateFields()
        self.updateRemindMeFields()
        self.updateAllWithoutDatePickersFields()
    }
    
    func updateActivity(){
        if self.reminderManager.isReminderLoadingWithKey(self.reminderKey) || self.reminderManager.isSyncing {
            self.showActivity()
        }else{
            self.hideActivity()
        }
    }
    
    func showActivity(){
        self.saveButton.enabled = false
        self.activityIndicator.startAnimating()
        self.navigationItem.titleView = activityIndicator
    }
    
    func hideActivity(){
        self.activityIndicator.stopAnimating()
        self.navigationItem.titleView = nil
        self.updateNavigationItemButtons()
    }
    
    func nextHourDate() -> NSDate? {
        let calendar = NSCalendar.currentCalendar()
        let date = NSDate()
        var minuteComponent = calendar.components(NSCalendarUnit.MinuteCalendarUnit, fromDate: date)
        
        let components = NSDateComponents()
        var minutesToNextHour = 60 - minuteComponent.minute
        if minutesToNextHour > 30 {
            components.minute = minutesToNextHour
        }else {
            components.minute = minutesToNextHour + 30
        }
        return calendar.dateByAddingComponents(components, toDate: date, options: nil)
    }
    
    func updateCollaborators(){
        self.collaborators = []
        self.collaboratorsView.removeAll()
        
        if !self.reminder.isCurrentUserAdmin() {
            self.collaboratorsView.addCollabaratorButton.hidden = true
        }
        
        if let collaborators = self.reminder.collaborators  {
            for collaborator in collaborators {
                var contact = self.contactsManager.getUDContactForUserId(collaborator)
                self.collaborators.append(contact.userId!)
                self.collaboratorsView.addCollabarator(collaborator, state: self.reminder.stateForUser(collaborator))
            }
        }
    }
    
    func updateTitle(){
        if self.reminder.title.isEmpty {
            self.taskTextView.text = ""
            self.saveButton.enabled = false
        } else {
            self.taskTextView.text = self.reminder.title
        }
        if self.reminder.createdAt != nil {
            let prettyDate = MHPrettyDate.prettyDateFromDate(self.reminder.createdAt, withFormat: MHPrettyDateFormatWithTime)
            self.createdAtLabel.text = "Created: \(prettyDate)"
        }
        self.taskTextView.editable = self.reminder.isCurrentUserAdmin()
    }
    
    
    func updateNotes(){
        if self.reminder.objectId == nil {
            self.cell(self.notesCell, setHidden: true)
        }else{
            self.cell(self.notesCell,setHidden: false)
            self.updateLastNote()
        }
    }
    
    func updateDueDateFields(){
        let isAdmin = self.reminder.isCurrentUserAdmin()
        var isDueDateSet = false
        if let dueDate = self.reminder.dueDate{
            isDueDateSet = true
            self.dueDateSwitch.setOn(true, animated: true)
            self.selectedDueDate = dueDate
            var interval:NSCalendarUnit!
            if let dueDateInterval = self.reminder.dueDateInterval {
                interval = NSCalendarUnit(self.reminder.dueDateInterval.unsignedLongValue)
            }
            self.selectedDuaDateRepeatInterval = interval
            self.dueDateLabel.text = dateFormatter.stringFromDate(self.reminder.dueDate)
            self.dueDateRepeatLabel.text = self.textForCelandarUnit(interval)
        }else {
            let nextHourDate = self.nextHourDate()
            if nextHourDate != nil{
                self.selectedDueDate = nextHourDate!
            }else {
                self.selectedDueDate = NSDate()
            }
            self.dueDateLabel.text = dateFormatter.stringFromDate(self.selectedDueDate)
        }
        self.cell(self.dueDateSwitchCell, setHidden: !isAdmin)
        self.cell(self.dueDateCell, setHidden:  !isDueDateSet)
        self.cell(self.dueDatePickerCell, setHidden: true)
        self.cell(self.dueDateRepeatCell, setHidden: !isDueDateSet)
        if !isAdmin {
            self.dueDateRepeatCell.accessoryType = UITableViewCellAccessoryType.None
        }else{
            self.dueDateRepeatCell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
        }
    }
    
    func updateRemindMeFields(){
        if self.reminder.isOnReminders {
            if let alarmDate = self.reminder.alarmDate {
                self.remindMeAlarmDateLabel.text = dateFormatter.stringFromDate(alarmDate)
                self.selectedAlarmDate = alarmDate
            }
        }
        self.addToMyRemindersSwitch.setOn(self.reminder.isOnReminders, animated: true)
        self.remindMeOnADaySwitch.setOn((self.reminder.alarmDate != nil), animated: true)
        self.cell(self.remindMeOnADayCell, setHidden: !self.reminder.isOnReminders)
        self.cell(self.remindMeAlarmDateCell, setHidden: (self.reminder.alarmDate == nil))
        self.cell(self.remindMeDatePickerCell, setHidden: true)
        self.cell(self.remindMeRepeatCell, setHidden: true) // not implemented yet
    }
    
    func scrollToBottom(){
        self.tableView.scrollRectToVisible(CGRect(x: 0, y: self.tableView.contentSize.height + 50, width: 10, height: 50), animated: true)
    }
    
    @IBAction func switchChanged(sender: UISwitch ) {
        if self.dueDateSwitch == sender{
            self.cell(self.dueDateCell, setHidden: !sender.on)
            self.cell(self.dueDateRepeatCell, setHidden: !sender.on)
            self.cell(self.dueDatePickerCell, setHidden: true)
            self.reloadDataAnimated(true)
            if sender.on {
                self.makeCellVisibleAfterDelay(self.dueDateSwitchCell)
            }
        }else if self.addToMyRemindersSwitch == sender {
            self.reminderManager.requestAccessToEventStore({ (success:Bool, _) -> Void in
                if success {
                    self.cell(self.remindMeOnADayCell, setHidden: !sender.on)
                    self.remindMeOnADaySwitch.setOn(false, animated: false)
                    self.cell(self.remindMeAlarmDateCell, setHidden: true)
                    self.cell(self.remindMeDatePickerCell, setHidden: true)
                    self.reloadDataAnimated(true)
                    if sender.on {
                        self.makeCellVisibleAfterDelay(self.remindMeOnADayCell)
                    }
                }else {
                    sender.setOn(false, animated: true)
                    TSMessage.showNotificationWithTitle("Error", subtitle: "Please give Reminders access to u.do from privacy settings", type: TSMessageNotificationType.Error)
                }
                
            })
        }else if self.remindMeOnADaySwitch == sender {
            if sender.on && self.remindMeAlarmDateLabel.text == "" {
                self.remindMeAlarmDateLabel.text = self.dueDateLabel.text
                self.selectedAlarmDate = self.selectedDueDate
            }
            if !sender.on {
                self.selectedAlarmDate = nil
            }
            self.cell(self.remindMeAlarmDateCell, setHidden: !sender.on)
            self.cell(self.remindMeDatePickerCell, setHidden: true)
            self.reloadDataAnimated(true)
            if sender.on {
                self.makeCellVisibleAfterDelay(self.remindMeAlarmDateCell)
            }
        }
        self.updateNavigationItemButtons()
    }
    
    func makeCellVisibleAfterDelay(cell:UITableViewCell){
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(0.2 * Double(NSEC_PER_SEC)))
        dispatch_after(delay,  dispatch_get_main_queue()) { () -> Void in
            if let indexPath = self.tableView.indexPathForCell(cell) {
                self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: true)
            }
        }
    }
    
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = self.tableView.cellForRowAtIndexPath(indexPath)
        if cell == self.notesCell {
            self.performSegueWithIdentifier("ShowNotes", sender: self)
        }else if cell == self.dueDateCell {
            if !self.reminder.isCurrentUserAdmin() {
                return
            }
            if self.dueDatePicker == nil {
                self.dueDatePicker = self.createDatePickerForCell(dueDatePickerCell)
            }
            let isHidden = self.cellIsHidden(self.dueDatePickerCell)
            self.cell(self.dueDatePickerCell, setHidden: !isHidden)
            self.reloadDataAnimated(true)
            if !self.cellIsHidden(self.dueDatePickerCell) {
                self.makeCellVisibleAfterDelay(self.dueDateCell)
            }
        }else if cell == self.remindMeAlarmDateCell{
            if self.remindMeDatePicker == nil {
                self.remindMeDatePicker = self.createDatePickerForCell(self.remindMeDatePickerCell)
            }
            let hidden = !self.cellIsHidden(self.remindMeDatePickerCell)
            self.cell(self.remindMeDatePickerCell, setHidden: hidden)
            self.reloadDataAnimated(true)
            if !self.cellIsHidden(self.remindMeDatePickerCell) {
                self.makeCellVisibleAfterDelay(self.remindMeAlarmDateCell)
            }
        }else if cell == self.remindMeRepeatCell || (cell == self.dueDateRepeatCell && self.reminder.isCurrentUserAdmin()) {
            self.performSegueWithIdentifier("ShowRepeatSelector", sender: self)
        }
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            self.taskTextView.superview?.layoutIfNeeded()
            var sizeThatFits = self.taskTextView.frame.size
            sizeThatFits.width = self.tableView.frame.size.width - 16 //margins
            sizeThatFits = self.taskTextView.sizeThatFits(sizeThatFits)
            return max(44,sizeThatFits.height + 28/*margins*/)
        }
        return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
    }
    
    func addCollabaratorButtonPressed(){
        self.performSegueWithIdentifier("SelectContact", sender: nil)
    }
    
    func collabaratorSelected(index:Int){
        var collaborator = self.collaborators[index]
        var contact = self.contactsManager.getUDContactForUserId(collaborator)
        var actionSheet = UIActionSheet()
        actionSheet.delegate = self
        if collaborator == PFUser.currentUser().username {
            actionSheet.title = "Me (\(collaborator))"
        } else if contact.apContact != nil {
            actionSheet.title = "\(contact.contactName()) (\(contact.userId))"
        }else{
            if let userPublic = contact.userPublic {
                actionSheet.title = "\(contact.name()) (\(contact.userId))"
            } else {
                actionSheet.title = "\(contact.userId)"
            }
        }
        var state = self.reminder.stateForUser(collaborator)
        if state == 1 {
            actionSheet.title += "\n Recevied"
        }else if state == 2 {
            actionSheet.title += "\n Completed"
        }else {
            //actionSheet.title += "\n Sent"
        }
        self.actionSheetOpertaion.removeAll(keepCapacity: true)
        if self.reminder.isCurrentUserAdmin() && self.collaborators[index] != PFUser.currentUser().username {
            let removeIndex = actionSheet.addButtonWithTitle("Remove User")
            self.actionSheetOpertaion[removeIndex] = { () -> Void in
                self.removeCollaboratorAtIndex(index)
            }
            actionSheet.destructiveButtonIndex = removeIndex
        }
        if !contactsManager.isUserRegistered(collaborator) {
            let invitationIndex = actionSheet.addButtonWithTitle("Send invitation")
            self.actionSheetOpertaion[invitationIndex] = { () -> Void in
                self.sendInvitation(collaborator)
            }
        }else {
            let profileIndex = actionSheet.addButtonWithTitle("Profile")
            self.actionSheetOpertaion[profileIndex] = { () -> Void in
                self.performSegueWithIdentifier("ShowProfileImageView", sender: contact)
            }
        }
        let copyPhoneNumber = actionSheet.addButtonWithTitle("Copy number")
        self.actionSheetOpertaion[copyPhoneNumber] = { () -> Void in
            UIPasteboard.generalPasteboard().string = contact.userId
        }
        var cancelIndex = actionSheet.addButtonWithTitle("Cancel")
        actionSheet.cancelButtonIndex = cancelIndex
        actionSheet.showInView(self.view)
        
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int){
        self.actionSheetOpertaion[buttonIndex]?()
    }
    
    func findIndexOfCollaborator(userId:String) -> Int{
        for var index = 0; index < self.collaborators.count; index++ {
            if self.collaborators[index] == userId {
                return index
            }
        }
        return -1
    }
    
    func textForCelandarUnit(unit:NSCalendarUnit?) -> String {
        if unit == nil {
            return "Never"
        }
        var text:String!
        switch unit! {
        case NSCalendarUnit.DayCalendarUnit:
            text = "Every Day"
        case NSCalendarUnit.WeekCalendarUnit:
            text = "Every Week"
        case NSCalendarUnit.MonthCalendarUnit:
            text = "Every Month"
        case NSCalendarUnit.YearCalendarUnit:
            text = "Every Year"
        default:
            text = "Never"
        }
        return text
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowRepeatSelector" {
            if let selectedRow = self.tableView.indexPathForSelectedRow() {
                let repeatSelectorVC = segue.destinationViewController as RepeatSelectorTableViewController
                var cell = self.tableView.cellForRowAtIndexPath(selectedRow)
                if cell == self.remindMeRepeatCell {
                    repeatSelectorVC.selectedCalendarUnit  = self.selectedAlarmDateRepeatInterval
                }else {
                    repeatSelectorVC.selectedCalendarUnit  = self.selectedDuaDateRepeatInterval
                }
            }
        }else if segue.identifier == "ShowNotes" {
            let notesVC = segue.destinationViewController as NotesViewController
            notesVC.title = self.reminder.title
            notesVC.reminderId = self.reminderKey
        }else if segue.identifier == "ShowProfileImageView" {
            let profileVC = segue.destinationViewController as ProfileImageViewController
            profileVC.udContact = sender as UDContact
        }
    }
    
    func addCollaborator(userId:String){
        self.collaborators.append(userId)
        self.collaboratorsView.addCollabarator(userId, state: 0)
        self.updateNavigationItemButtons()
    }
    func removeCollaboratorAtIndex(index:Int){
        self.collaborators.removeAtIndex(index)
        self.collaboratorsView.removeCollabaratorAtIndex(index)
        self.updateNavigationItemButtons()
    }
    
    @IBAction func unwind(unwindSegue:UIStoryboardSegue){
        if unwindSegue.identifier == "ContactSelected"{
            let contactDetailsVC = unwindSegue.sourceViewController as ContactDetailsViewController
            var number = contactDetailsVC.contact.phones[contactDetailsVC.tableView.indexPathForSelectedRow()!.row] as String
            var userId = self.contactsManager.getUserIdFromPhoneNumber(number)
            if !contactsManager.isUserRegistered(userId) {
                self.sendInvitationToNumber = userId
            }
            if self.findIndexOfCollaborator(userId) != -1 {
                self.collaboratorsView.makeContactAtIndexVisible(self.findIndexOfCollaborator(userId))
            }else{
                self.addCollaborator(userId)
            }
        }else if unwindSegue.identifier == "RepeatIntervalSelected" {
            if let selectedRow = self.tableView.indexPathForSelectedRow() {
                let repeatSelectorVC = unwindSegue.sourceViewController as RepeatSelectorTableViewController
                var cell = self.tableView.cellForRowAtIndexPath(selectedRow)
                if cell == self.remindMeRepeatCell {
                    self.selectedAlarmDateRepeatInterval = repeatSelectorVC.selectedCalendarUnit
                    self.remindMeRepeatLabel.text = self.textForCelandarUnit(self.selectedAlarmDateRepeatInterval)
                }else {
                    self.selectedDuaDateRepeatInterval = repeatSelectorVC.selectedCalendarUnit
                    self.dueDateRepeatLabel.text = self.textForCelandarUnit(self.selectedDuaDateRepeatInterval)
                }
            }
        }
    }
    
    
    func touchOutside(sender:UITapGestureRecognizer) {
        self.taskTextView.endEditing(false)
    }
    
    
    @IBAction func saveButtonPressed(sender: AnyObject) {
        self.saveReminder()
        self.performSegueWithIdentifier("BackToMain", sender: nil)
    }
    
    
    func textViewDidBeginEditing(textView: UITextView) {
        var rect = textView.convertRect(textView.frame, toView: self.tableView)
        self.tableView.scrollRectToVisible(rect, animated: true)
    }
    
    
    func textViewDidChange(textView: UITextView!) {
        if textView.text.isEmpty {
            self.saveButton.enabled = false
        }else{
            self.saveButton.enabled = true
        }
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
        self.updateNavigationItemButtons()
    }
    
    @IBAction func dateChanged(sender: UIDatePicker) {
        if self.dueDatePicker != nil  &&  self.dueDatePicker == sender {
            self.dueDateLabel.text = dateFormatter.stringFromDate(sender.date)
            self.selectedDueDate = sender.date
        }else if self.remindMeDatePicker != nil && self.remindMeDatePicker == sender {
            self.remindMeAlarmDateLabel.text = dateFormatter.stringFromDate(sender.date)
            self.selectedAlarmDate = sender.date
        }
        self.updateNavigationItemButtons()
    }
    
    func createDatePickerForCell(cell:UIView) -> UIDatePicker {
        var picker = UIDatePicker()
        picker.addTarget(self, action: "dateChanged:", forControlEvents: UIControlEvents.ValueChanged)
        picker.setDate(self.selectedDueDate, animated: false)
        cell.addSubview(picker)
        
        picker.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        var alignX = NSLayoutConstraint(item: picker, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: cell, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0)
        cell.addConstraint(alignX)
        
        var alignY = NSLayoutConstraint(item: picker, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: cell, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0)
        cell.addConstraint(alignY)
        return picker
    }
    
    func sendInvitation(number:String){
        if MFMessageComposeViewController.canSendText() {
            let recipents = [number]
            var messageController = MFMessageComposeViewController()
            messageController.messageComposeDelegate = self
            messageController.recipients = recipents
            messageController.body = self.contactsManager.getInvitationLetter()
            self.presentViewController(messageController, animated: true, completion: nil)
        }
    }
    
    
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        if result.value == MessageComposeResultFailed.value{
            TSMessage.showNotificationWithTitle("Error", subtitle: "Failed to send message", type: TSMessageNotificationType.Error)
            controller.dismissViewControllerAnimated(true, completion: nil)
        }else if result.value == MessageComposeResultSent.value {
            self.contactsManager.invitationSent(controller.recipients)
            controller.dismissViewControllerAnimated(true, completion: nil)
        }else if result.value == MessageComposeResultCancelled.value {
            controller.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    func saveReminder(){
        if self.reminder.title != self.taskTextView.text {
            self.reminder.title = self.taskTextView.text
        }
        if self.dueDateSwitch.on {
            if (reminder.dueDate == nil || ( self.reminder.dueDate != nil && !self.reminder.dueDate.isEqualToDate(self.selectedDueDate))) {
                self.reminder.dueDate = self.selectedDueDate
            }
            if (self.reminder.dueDateInterval == nil && self.selectedDuaDateRepeatInterval != nil) || (self.reminder.dueDateInterval != nil && self.selectedDuaDateRepeatInterval == nil) || (self.reminder.dueDateInterval != nil && self.selectedAlarmDateRepeatInterval != nil && !self.reminder.dueDateInterval.isEqual(self.selectedAlarmDateRepeatInterval.rawValue)) {
                if self.selectedDuaDateRepeatInterval == nil {
                    self.reminder.dueDateInterval = nil
                }else {
                    self.reminder.dueDateInterval = self.selectedDuaDateRepeatInterval.rawValue
                }
            }
        }else if reminder.dueDate != nil {
            reminder.dueDate = nil
        }
        //only admin can change collaborator
        var addedItemsAfterSave:NSArray!
        if self.reminder.collaborators.first? == PFUser.currentUser().username {
            // parse cannot hande addAtomic and removeAtomic at the same time
            // do addAtomic after save
            var removedItems = NSMutableArray(array: self.reminder.collaborators)
            removedItems.removeObjectsInArray(self.collaborators)
            if removedItems.count > 0 {
                self.reminder.removeObjectsInArray(removedItems, forKey: kReminderCollaborators)
            }
            var addedItems = NSMutableArray(array: self.collaborators)
            addedItems.removeObjectsInArray(reminder.collaborators)
            if removedItems.count == 0 && addedItems.count > 0 {
                self.reminder.addUniqueObjectsFromArray(addedItems, forKey: kReminderCollaborators)
            } else if removedItems.count > 0 && addedItems.count > 0 {
                addedItemsAfterSave = addedItems
            }
        }
        if !self.remindMeOnADaySwitch.on {
            self.selectedAlarmDate = nil
        }
        self.reminderManager.saveReminder(reminder, addToMyReminders: self.addToMyRemindersSwitch.on, alarmDate: self.selectedAlarmDate, repeatInterval: self.selectedAlarmDateRepeatInterval, { (success:Bool, error:NSError!) -> Void in
            if success {
                if addedItemsAfterSave != nil {
                    self.reminder.addUniqueObjectsFromArray(addedItemsAfterSave, forKey: kReminderCollaborators)
                    self.reminder.saveEventually()
                }
            }
        })
    }
    
}


protocol CollabaratorViewDelegate{
    func addCollabaratorButtonPressed()
    func collabaratorSelected(index:Int)
}

var AddCollaboratorButtonImage = UIImage(named: "add")?.imageTintedWithColor(AppTheme.tintColor)

class CollabaratorView:UIScrollView {
    private var addCollabaratorButton:UIButton!
    private let imgSize = CGFloat(60)
    private let padding = CGFloat(10)
    private var collabarators = [(String,UIButton)]()
    
    var contactsManager = ContactsManager.sharedInstance
    
    var collabaratorDelegate:CollabaratorViewDelegate!
    
    override func awakeFromNib() {
        self.addCollabaratorButton = UIButton(frame: CGRect(x: self.padding, y: self.padding, width: self.imgSize, height: self.imgSize))
        self.addCollabaratorButton.setImage(AddCollaboratorButtonImage, forState: UIControlState.Normal)
        self.addCollabaratorButton.addTarget(self, action: "addCollabaratorButtonPressed:", forControlEvents: UIControlEvents.TouchUpInside)
        self.addSubview(self.addCollabaratorButton)
        self.alwaysBounceVertical = false
        self.alwaysBounceHorizontal = true
    }
    
    func refresh(){
        //todo refresh user names
    }
    
    func addCollabaratorButtonPressed(sender:UIButton){
        self.collabaratorDelegate.addCollabaratorButtonPressed()
    }
    
    // state : 0 none
    // state : 1 received
    // state : 2 done
    func addCollabarator(userId:String, state: Int){
        var cView = UIView(frame: CGRect(x: self.nextXPosiotion(), y: 0, width: self.imgSize, height: self.bounds.height))
        cView.backgroundColor = UIColor.clearColor()
        self.addSubview(cView)
        var cButton = UIButton(frame: CGRect(x: 0, y: self.padding, width: self.imgSize, height: self.imgSize))
        cButton.layer.backgroundColor = UIColor.clearColor().CGColor
        cButton.layer.cornerRadius = CGFloat(imgSize/2)
        cButton.layer.masksToBounds = true
        var udImageView = UDContactImageView(image: DefaultAvatarImage)
        udImageView.frame = CGRect(x: 0, y: 0, width: self.imgSize, height: self.imgSize)
        cButton.addSubview(udImageView)
        var contact = self.contactsManager.getUDContactForUserId(userId)
        udImageView.loadWithContact(contact, showIndicator: false)
        cButton.layer.borderWidth = 5
        if state == 2 {
            cButton.layer.borderColor = AppTheme.doneColor.CGColor
        }else if state == 1 {
            cButton.layer.borderColor = AppTheme.receivedColor.CGColor
        }else {
            cButton.layer.borderColor = AppTheme.notReceivedColor.CGColor
        }
        if (!self.contactsManager.isUserRegistered(userId) && userId != PFUser.currentUser().username ){
            cButton.layer.borderColor = AppTheme.unRegisteredUserColor.CGColor
        }
        cButton.addTarget(self, action: "collabaratorPressed:", forControlEvents: UIControlEvents.TouchUpInside)
        cView.addSubview(cButton)
        var nameLabel = UILabel(frame: CGRect(x: 0 , y: self.padding + self.imgSize, width: self.imgSize, height: 30))
        nameLabel.font = UIFont.systemFontOfSize(10)
        nameLabel.text = contact.name()
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        nameLabel.textAlignment = NSTextAlignment.Center
        if (!contactsManager.isUserRegistered(userId) && userId != PFUser.currentUser().username ){
            nameLabel.textColor = UIColor.redColor()
        }
        cView.addSubview(nameLabel)
        self.collabarators.append((userId,cButton))
        self.setContentWidthAndAddButtonPosition()
        self.scrollRectToVisible(self.addCollabaratorButton.frame, animated: true)
    }
    
    func removeCollabaratorAtIndex(index:Int){
        self.collabarators[index].1.superview?.removeFromSuperview()
        for var i = index + 1; i < self.collabarators.count; i++ {
            var cView = self.collabarators[i].1.superview!
            cView.frame.origin.x = cView.frame.origin.x - cView.frame.width - self.padding
        }
        self.collabarators.removeAtIndex(index)
        self.setContentWidthAndAddButtonPosition()
    }
    
    func removeAll(){
        for var index = self.collabarators.count - 1; index >= 0; index-- {
            self.removeCollabaratorAtIndex(index)
        }
    }
    
    func makeContactAtIndexVisible(index:Int){
        self.scrollRectToVisible(self.collabarators[index].1.frame, animated: true)
    }
    
    private func nextXPosiotion() -> CGFloat {
        return (CGFloat(self.collabarators.count) * ( imgSize + padding)) + padding
    }
    
    private func setContentWidthAndAddButtonPosition(){
        self.addCollabaratorButton.frame.origin.x = self.nextXPosiotion()
        self.contentSize = CGSize(width: self.contentSize() , height: self.bounds.height - 1)
    }
    
    private func contentSize() -> CGFloat {
        var addButtonWidth:CGFloat!
        if self.addCollabaratorButton.hidden {
            addButtonWidth = CGFloat(0)
        }else{
            addButtonWidth = self.addCollabaratorButton.bounds.width
        }
        return self.nextXPosiotion() + addButtonWidth + self.padding
    }
    
    
    func collabaratorPressed( button:UIButton ){
        for var index = 0; index < self.collabarators.count; index++ {
            if self.collabarators[index].1 == button {
                self.collabaratorDelegate.collabaratorSelected(index)
                return
            }
        }
    }
}

class RepeatSelectorTableViewController : UITableViewController {
    var selectedCalendarUnit:NSCalendarUnit!
    
    func indexPathForSelectedCalendarUnit() -> NSIndexPath {
        var index:Int!
        if selectedCalendarUnit == nil {
            index = 0
        }else {
            switch selectedCalendarUnit {
            case NSCalendarUnit.DayCalendarUnit:
                index = 1
            case NSCalendarUnit.WeekCalendarUnit:
                index = 2
            case NSCalendarUnit.MonthCalendarUnit:
                index = 3
            case NSCalendarUnit.YearCalendarUnit:
                index = 4
            default:
                index = 0
            }
        }
        return NSIndexPath(forRow: index, inSection: 0)
    }
    
    func setCalendarUnitForIndexPath(indexPath:NSIndexPath) {
        switch indexPath.row {
        case 1:
            self.selectedCalendarUnit = NSCalendarUnit.DayCalendarUnit
        case 2:
            self.selectedCalendarUnit = NSCalendarUnit.WeekCalendarUnit
        case 3:
            self.selectedCalendarUnit = NSCalendarUnit.MonthCalendarUnit
        case 4:
            self.selectedCalendarUnit = NSCalendarUnit.YearCalendarUnit
        default:
            self.selectedCalendarUnit = nil
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        if self.indexPathForSelectedCalendarUnit() == indexPath {
            cell.accessoryType = UITableViewCellAccessoryType.Checkmark
        }else {
            cell.accessoryType = UITableViewCellAccessoryType.None
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var previousSelection = self.tableView.cellForRowAtIndexPath(self.indexPathForSelectedCalendarUnit())
        previousSelection?.accessoryType = UITableViewCellAccessoryType.None
        
        self.setCalendarUnitForIndexPath(indexPath)
        var currentSelection = self.tableView.cellForRowAtIndexPath(indexPath)
        currentSelection?.accessoryType = UITableViewCellAccessoryType.Checkmark
        
        self.performSegueWithIdentifier("RepeatIntervalSelected", sender: nil)
    }
}

