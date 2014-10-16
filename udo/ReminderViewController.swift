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
    
    @IBOutlet weak var dueDateLabel: UILabel!
    
    @IBOutlet weak var dueDateSwitchAdmin: UISwitch!
    @IBOutlet weak var dueDateLabelAdmin: UILabel!
    var dueDatePickerAdmin: UIDatePicker!
    
    
    @IBOutlet weak var addToMyRemindersSwitch: UISwitch!
    @IBOutlet weak var remindMeOnADaySwitch: UISwitch!
    @IBOutlet weak var remindMeAlarmDateLabel: UILabel!
    var remindMeDatePicker: UIDatePicker!
    
    
    @IBOutlet weak var dueDateLabelCell: UITableViewCell!
    
    @IBOutlet weak var dueDateSwitchAdminCell: UITableViewCell!
    @IBOutlet weak var dueDateLabelAdminCell: UITableViewCell!
    @IBOutlet weak var dueDatePickerAdminCell: UITableViewCell!
    
    @IBOutlet weak var remindMeOnADayCell: UITableViewCell!
    @IBOutlet weak var remindMeAlarmDateLabelCell: UITableViewCell!
    @IBOutlet weak var remindMeDatePickerCell: UITableViewCell!
    
    private let dateFormatter = NSDateFormatter()
    private var contactsManager = ContactsManager.sharedInstance
    private var reminderManager = ReminderManager.sharedInstance
    var reminderKey:String!
    private var reminder: Reminder!
    private var collaborators:[String] = []
    private var actionSheetOpertaion = Dictionary<Int,()->Void>()
    private var sendInvitationToNumber:ContactNumber!
    
    private var defaulImage = UIImage(named: "default-avatar")
    @IBOutlet weak var calendarIconImageView: UIImageView!
    @IBOutlet weak var notificationIconImageView: UIImageView!
    
    private var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
    
    private var selectedDueDate:NSDate!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UITapGestureRecognizer(target: self, action:"touchOutside:")
        tap.cancelsTouchesInView = false
        self.tableView.addGestureRecognizer(tap)
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
        
        
        //empty means not set yet
        self.remindMeAlarmDateLabel.text = ""
        
        self.collaboratorsView.collabaratorDelegate = self
        
        self.hideSectionsWithHiddenRows = true
        self.insertTableViewRowAnimation = UITableViewRowAnimation.Top
        self.deleteTableViewRowAnimation = UITableViewRowAnimation.Automatic
        
        var calendarImage = UIImage(named: "calendar32").imageTintedWithColor(AppTheme.iconMaskColor)
        self.calendarIconImageView.image = calendarImage
        var notificationImage = UIImage(named: "notifications32").imageTintedWithColor(AppTheme.iconMaskColor)
        self.notificationIconImageView.image = notificationImage
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "remindersChangedNotification:", name: kRemindersChangedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reminderLoadingNotification:", name: kReminderLoadingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reminderLoadingFinishedNotification:", name: kReminderLoadingFinishedNotification, object: nil)
        
        self.prepareReminder()
        self.updateAllFields()
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.destinationViewController is RemindersMainViewController {
            NSNotificationCenter.defaultCenter().removeObserver(self)
        }
    }
    
    
    override func viewDidAppear(animated: Bool) {
        if self.sendInvitationToNumber != nil {
            self.sendInvitation(sendInvitationToNumber)
            self.sendInvitationToNumber = nil
        }
    }
    
    func reminderLoadingNotification(notification:NSNotification){
        var key = notification.object as String
        if self.reminder.key() == key {
            self.showActivity()
        }
    }
    
    func reminderLoadingFinishedNotification(notification:NSNotification){
        var key = notification.object as String
        if self.reminder.key() == key {
            self.prepareReminder()
            self.updateAllFields()
        }
    }
    
    func remindersChangedNotification(notification:NSNotification){
        var change = notification.object as RemindersChanged!
        for key in change.updates {
            if key == self.reminder.key() {
                self.prepareReminder()
                self.updateAllFields()
            }
        }
    }
    
    func showActivity(){
        self.saveButton.enabled = false
        self.activityIndicator.startAnimating()
        self.navigationItem.titleView = activityIndicator
    }
    
    func hideActivity(){
        self.saveButton.enabled = true
        self.activityIndicator.stopAnimating()
        self.navigationItem.titleView = nil
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
                var number = self.contactsManager.getContactNumberForUserId(collaborator)
                self.collaborators.append(number.userId!)
                self.collaboratorsView.addCollabarator(number, done: self.reminder.isUserDone(number.userId))
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
        self.taskTextView.editable = self.reminder.isCurrentUserAdmin()
    }
    
    func updateDueDateFields(){
        let isAdmin = self.reminder.isCurrentUserAdmin()
        var isDueDateSet = false
        if let dueDate = self.reminder.dueDate{
            isDueDateSet = true
            self.dueDateLabel.text = dateFormatter.stringFromDate(dueDate)
            self.dueDateSwitchAdmin.setOn(true, animated: true)
            self.dueDateLabelAdmin.text = dateFormatter.stringFromDate(dueDate)
            self.selectedDueDate = dueDate
        }else {
            if let nextHourDate = self.nextHourDate(){
                self.selectedDueDate = nextHourDate
            }else {
                self.selectedDueDate = NSDate()
            }
            self.dueDateLabelAdmin.text = dateFormatter.stringFromDate(selectedDueDate)
        }
        
        self.cell(self.dueDateLabelCell, setHidden: isAdmin | !isDueDateSet)
        self.cell(self.dueDateSwitchAdminCell, setHidden: !isAdmin)
        self.cell(self.dueDateLabelAdminCell, setHidden: !isAdmin | !isDueDateSet)
        self.cell(self.dueDatePickerAdminCell, setHidden: true)
    }
    
    func updateRemindMeFields(){
        var isOnMyReminders = false
        var isAlarmSet = false
        if self.reminder.objectId != nil {
            var eventStore = EventStoreManager.sharedInstance
            if eventStore.isStored(self.reminder.key()) {
                isOnMyReminders = true
                if let alarmDate = eventStore.getAlarmDateForKey(self.reminder.key()){
                    isAlarmSet = true
                    self.remindMeAlarmDateLabel.text = dateFormatter.stringFromDate(alarmDate)
                    self.remindMeDatePicker.date = alarmDate
                    
                }else {
                    isAlarmSet = false
                }
            }
        }
        self.addToMyRemindersSwitch.setOn(isOnMyReminders, animated: true)
        self.remindMeOnADaySwitch.setOn(isAlarmSet, animated: true)
        self.cell(self.remindMeOnADayCell, setHidden: !isOnMyReminders)
        self.cell(self.remindMeAlarmDateLabelCell, setHidden: !isAlarmSet)
        self.cell(self.remindMeDatePickerCell, setHidden: true)
    }
    
    func prepareReminder(){
        if self.reminderKey == nil {
            self.reminder = Reminder()
            self.reminder.title = ""
            self.reminder.collaborators = [PFUser.currentUser().username]
        }else {
            self.reminder = self.reminderManager.getReminder(self.reminderKey)
        }
    }
    
    // slows down the load proccess
    func updateAllWithoutDatePickersFields(){
        if self.reminderManager.isReminderLoadingWithKey(self.reminder.key()) {
            self.showActivity()
        }else{
            self.hideActivity()
        }
        self.updateCollaborators()
        self.updateTitle()
        self.reloadDataAnimated(false)
    }
    
    func updateAllFields(){
        self.updateDueDateFields()
        self.updateRemindMeFields()
        self.updateAllWithoutDatePickersFields()
    }
    
    func reminderChangedNotificationReceived(notification: NSNotification){
        if self.reminder.objectId == nil {
            return
        }
        let newReminders = notification.object as [Reminder]
        for newReminder in newReminders {
            if (newReminder.objectId == self.reminder.objectId && newReminder.updatedAt.compare(self.reminder.updatedAt) == NSComparisonResult.OrderedDescending ){
                self.reminder = newReminder
                self.updateAllFields()
            }
        }
    }
    
    func addCollabaratorButtonPressed(){
        self.performSegueWithIdentifier("SelectContact", sender: nil)
    }
    
    func collabaratorSelected(index:Int){
        
        var collaborator = self.collaborators[index]
        var number = self.contactsManager.getContactNumberForUserId(collaborator)
        var actionSheet = UIActionSheet()
        actionSheet.delegate = self
        if let name = number.contact.name {
            actionSheet.title = "\(name)(\(number.userId))"
        }else{
            actionSheet.title = "\(number.userId)"
        }
        if self.collaborators[index] != PFUser.currentUser().username {
            if self.reminder.isCurrentUserAdmin() {
                var removeIndex = actionSheet.addButtonWithTitle("Remove User")
                self.actionSheetOpertaion[removeIndex] = { () -> Void in
                    self.collaborators.removeAtIndex(index)
                    self.collaboratorsView.removeCollabaratorAtIndex(index)
                }
                actionSheet.destructiveButtonIndex = removeIndex
            }
            if !contactsManager.isNumberRegistered(number) {
                var invitationIndex = actionSheet.addButtonWithTitle("Send invitation")
                self.actionSheetOpertaion[invitationIndex] = { () -> Void in
                    self.sendInvitation(number)
                }
            }
        }
        var cancelIndex = actionSheet.addButtonWithTitle("Cancel")
        actionSheet.cancelButtonIndex = cancelIndex
        actionSheet.showInView(self.view)
        
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int){
        self.actionSheetOpertaion[buttonIndex]?()
    }
    
    func findIndexOfCollaborator(number:ContactNumber) -> Int{
        for var index = 0; index < self.collaborators.count; index++ {
            if self.collaborators[index] == number.userId {
                return index
            }
        }
        return -1
    }
    
    
    @IBAction func unwind(unwindSegue:UIStoryboardSegue){
        if unwindSegue.identifier == "ContactSelected"{
            let contactDetailsVC = unwindSegue.sourceViewController as ContactDetailsViewController
            let number = contactDetailsVC.contact.numbers[contactDetailsVC.tableView.indexPathForSelectedRow()!.row]
            if !contactsManager.isNumberRegistered(number) {
                self.sendInvitationToNumber = number
            }
            if self.findIndexOfCollaborator(number) != -1 {
                self.collaboratorsView.makeContactAtIndexVisible(self.findIndexOfCollaborator(number))
            }else{
                self.collaborators.append(number.userId)
                self.collaboratorsView.addCollabarator(number, done:false)
            }
        }
    }
    
    
    func touchOutside(sender:UITapGestureRecognizer) {
        self.taskTextView.endEditing(false)
    }
    
    
    @IBAction func saveButtonPressed(sender: AnyObject) {
        self.saveReminder()
        self.performSegueWithIdentifier("SaveItemEdit", sender: nil)
    }
    
    @IBAction func switchChanged(sender: UISwitch ) {
        if self.dueDateSwitchAdmin == sender{
            self.cell(self.dueDateLabelAdminCell, setHidden: !sender.on)
            self.cell(self.dueDatePickerAdminCell, setHidden: true)
            self.reloadDataAnimated(true)
            if !self.cellIsHidden(self.dueDateLabelAdminCell) {
                var indexPath = self.tableView.indexPathForCell(self.dueDateLabelAdminCell)
                self.tableView.scrollToRowAtIndexPath(indexPath!, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
            }
        }else if self.addToMyRemindersSwitch == sender {
            EventStoreManager.sharedInstance.requestAccess({ (success:Bool, _) -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if success {
                        self.cell(self.remindMeOnADayCell, setHidden: !sender.on)
                        self.remindMeOnADaySwitch.setOn(false, animated: false)
                        self.cell(self.remindMeAlarmDateLabelCell, setHidden: true)
                        self.cell(self.remindMeDatePickerCell, setHidden: true)
                        self.reloadDataAnimated(true)
                        if !self.cellIsHidden(self.remindMeOnADayCell) {
                            var indexPath = self.tableView.indexPathForCell(self.remindMeOnADayCell)
                            self.tableView.scrollToRowAtIndexPath(indexPath!, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
                        }
                    }else {
                        sender.setOn(!sender.on, animated: true)
                        UIAlertView(title: "Warning", message: "Please give Reminders access to u.do from privacy settings", delegate: nil, cancelButtonTitle: "Ok").show()
                    }
                })
            })
        }else if self.remindMeOnADaySwitch == sender {
            if sender.on && self.remindMeAlarmDateLabel.text == "" {
                self.remindMeAlarmDateLabel.text = self.dueDateLabelAdmin.text
            }
            self.cell(self.remindMeAlarmDateLabelCell, setHidden: !sender.on)
            self.cell(self.remindMeDatePickerCell, setHidden: true)
            self.reloadDataAnimated(true)
            if !self.cellIsHidden(self.remindMeAlarmDateLabelCell) {
                var indexPath = self.tableView.indexPathForCell(self.remindMeAlarmDateLabelCell)
                self.tableView.scrollToRowAtIndexPath(indexPath!, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
            }
        }
    }
    
    
    func textViewDidChange(textView: UITextView!) {
        if textView.text.isEmpty {
            self.saveButton.enabled = false
        }else{
            self.saveButton.enabled = true
        }
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
    }
    
    @IBAction func dateChanged(sender: UIDatePicker) {
        if self.dueDatePickerAdmin == sender {
            self.dueDateLabelAdmin.text = dateFormatter.stringFromDate(sender.date)
            self.selectedDueDate = sender.date
        }else if self.remindMeDatePicker == sender {
            self.remindMeAlarmDateLabel.text = dateFormatter.stringFromDate(sender.date)
        }
    }
    
    func createDatePickerForCell(cell:UIView) -> UIDatePicker {
        var picker = UIDatePicker()
        picker.setDate(self.selectedDueDate, animated: false)
        cell.addSubview(picker)
        
        picker.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        var alignX = NSLayoutConstraint(item: picker, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: cell, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0)
        cell.addConstraint(alignX)
        
        var alignY = NSLayoutConstraint(item: picker, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: cell, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0)
        cell.addConstraint(alignY)
        return picker
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 3 && indexPath.row == 1 {
            if self.dueDatePickerAdmin == nil {
               self.dueDatePickerAdmin = self.createDatePickerForCell(dueDatePickerAdminCell)
            }
            let isHidden = self.cellIsHidden(self.dueDatePickerAdminCell)
            self.cell(self.dueDatePickerAdminCell, setHidden: !isHidden)
            self.reloadDataAnimated(true)
            if isHidden {
                var indexPath = self.tableView.indexPathForCell(self.dueDatePickerAdminCell)
                self.tableView.scrollToRowAtIndexPath(indexPath!, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
            }
        }else if indexPath.section == 4 && indexPath.row == 2 {
            if self.remindMeDatePicker == nil {
                self.remindMeDatePicker = self.createDatePickerForCell(self.remindMeDatePickerCell)
            }
            let hidden = !self.cellIsHidden(self.remindMeDatePickerCell)
            self.cell(self.remindMeDatePickerCell, setHidden: hidden)
            self.reloadDataAnimated(true)
            if !self.cellIsHidden(self.remindMeDatePickerCell) {
                var indexPath = self.tableView.indexPathForCell(self.remindMeDatePickerCell)
                self.tableView.scrollToRowAtIndexPath(indexPath!, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
            }
        }
    }
    
    
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 1 {
            self.taskTextView.superview?.layoutIfNeeded()
            var sizeThatFits = self.taskTextView.frame.size
            sizeThatFits.width = self.tableView.frame.size.width - 16 //margins
            sizeThatFits = self.taskTextView.sizeThatFits(sizeThatFits)
            return max(44,sizeThatFits.height + 20/*margins*/)
        }
        return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
    }
    
    
    func sendInvitation(number:ContactNumber){
        if MFMessageComposeViewController.canSendText() {
            let recipents = [number.original]
            var messageController = MFMessageComposeViewController()
            messageController.messageComposeDelegate = self
            messageController.recipients = recipents
            messageController.body = self.contactsManager.getInvitationLetter()
            self.presentViewController(messageController, animated: true, completion: nil)
        }
    }
    
    
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        if result.value == MessageComposeResultFailed.value{
            UIAlertView(title: "Error", message: "Failed to send message", delegate: nil, cancelButtonTitle: "Continue").show()
            controller.dismissViewControllerAnimated(true, completion: nil)
        }else if result.value == MessageComposeResultSent.value {
            self.contactsManager.invitationSent(controller.recipients)
            controller.dismissViewControllerAnimated(true, completion: nil)
            self.performSegueWithIdentifier("ContactSelected", sender: nil)
        }else if result.value == MessageComposeResultCancelled.value {
            controller.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    func saveReminder(){
        if self.reminder.title != self.taskTextView.text {
            self.reminder.title = self.taskTextView.text
        }
        if self.dueDateSwitchAdmin.on {
            if (reminder.dueDate == nil || ( reminder.dueDate != nil && !reminder.dueDate.isEqualToDate(self.dueDatePickerAdmin.date))) {
                reminder.dueDate = self.dueDatePickerAdmin.date
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
        if !self.reminder.isDirty() {
            self.saveEventStoreChanges()
        }else {
            self.reminderManager.saveReminder(reminder, resultBlock: { (success:Bool, error:NSError!) -> Void in
                if success {
                    if addedItemsAfterSave != nil {
                        self.reminder.addUniqueObjectsFromArray(addedItemsAfterSave, forKey: kReminderCollaborators)
                        self.reminder.saveEventually()
                    }
                    self.saveEventStoreChanges()
                }
            })
        }
    }
    
    func saveEventStoreChanges(){
        var eventStoreManager = EventStoreManager.sharedInstance
        if self.addToMyRemindersSwitch.on {
            var alarmDate:NSDate!
            if self.remindMeOnADaySwitch.on {
                alarmDate = self.remindMeDatePicker.date
            }
            eventStoreManager.upsertWithTitle(self.reminder.title, andAlarmDate: alarmDate, forKey: self.reminder.key())
        }else if eventStoreManager.isStored(reminder.key()){
            eventStoreManager.remove(reminder.key())
        }
    }
}


protocol CollabaratorViewDelegate{
    func addCollabaratorButtonPressed()
    func collabaratorSelected(index:Int)
}

var AddCollaboratorButtonImage = UIImage(named: "add").imageTintedWithColor(AppTheme.tintColor)

class CollabaratorView:UIScrollView {
    private var addCollabaratorButton:UIButton!
    private var defaulImage = UIImage(named: "default-avatar")
    private let imgSize = CGFloat(60)
    private let padding = CGFloat(10)
    private var collabarators = [(ContactNumber,UIButton)]()
    
    var contactsManagaer = ContactsManager.sharedInstance
    
    var collabaratorDelegate:CollabaratorViewDelegate!
    
    override func awakeFromNib() {
        self.addCollabaratorButton = UIButton(frame: CGRect(x: self.padding, y: self.padding, width: self.imgSize, height: self.imgSize))
        self.addCollabaratorButton.setImage(AddCollaboratorButtonImage, forState: UIControlState.Normal)
        self.addCollabaratorButton.addTarget(self, action: "addCollabaratorButtonPressed:", forControlEvents: UIControlEvents.TouchUpInside)
        self.addSubview(self.addCollabaratorButton)
        self.alwaysBounceVertical = false
    }
    
    func addCollabaratorButtonPressed(sender:UIButton){
        self.collabaratorDelegate.addCollabaratorButtonPressed()
    }
    
    func addCollabarator(number:ContactNumber, done: Bool){
        var cView = UIView(frame: CGRect(x: self.nextXPosiotion(), y: 0, width: self.imgSize, height: self.bounds.height))
        self.addSubview(cView)
        var cButton = UIButton(frame: CGRect(x: 0, y: self.padding, width: self.imgSize, height: self.imgSize))
        cButton.layer.backgroundColor = UIColor.clearColor().CGColor
        cButton.layer.cornerRadius = CGFloat(imgSize/2)
        cButton.layer.masksToBounds = true
        if let img = number.contact.image {
            cButton.setImage(img, forState: UIControlState.Normal)
        }else {
            cButton.setImage(defaulImage, forState: UIControlState.Normal)
        }
        cButton.layer.borderWidth = 5
        if done {
            cButton.layer.borderColor = AppTheme.doneColor.CGColor
        }else {
            cButton.layer.borderColor = AppTheme.unDoneColor.CGColor
        }
        if (!contactsManagaer.isNumberRegistered(number) && number.userId != PFUser.currentUser().username ){
            cButton.layer.borderColor = AppTheme.unRegisteredUserColor.CGColor
        }
        cButton.addTarget(self, action: "collabaratorPressed:", forControlEvents: UIControlEvents.TouchUpInside)
        cView.addSubview(cButton)
        var nameLabel = UILabel(frame: CGRect(x: 0 , y: self.padding + self.imgSize, width: self.imgSize, height: 30))
        nameLabel.font = UIFont.systemFontOfSize(10)
        if let name = number.contact.name {
            nameLabel.text = name
        }else{
            nameLabel.text = number.userId
        }
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        nameLabel.textAlignment = NSTextAlignment.Center
        if (!contactsManagaer.isNumberRegistered(number) && number.userId != PFUser.currentUser().username ){
            nameLabel.textColor = UIColor.redColor()
        }
        cView.addSubview(nameLabel)
        self.collabarators.append((number,cButton))
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
