//
//  TaskEditViewController.swift
//  udo
//
//  Created by Osman Alpay on 06/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

protocol CollabaratorViewDelegate{
    func addCollabaratorButtonPressed()
    func collabaratorSelected(index:Int)
}

class CollabaratorView:UIScrollView {
    private var addCollabaratorButton:UIButton!
    private var defaulImage = UIImage(named: "default-avatar")
    private let imgSize = CGFloat(60)
    private let padding = CGFloat(10)
    private var collabarators = [(ContactNumber,UIButton)]()
    
    var collabaratorDelegate:CollabaratorViewDelegate!
    
    override func awakeFromNib() {
        self.addCollabaratorButton = UIButton(frame: CGRect(x: self.padding, y: self.padding, width: self.imgSize, height: self.imgSize))
        self.addCollabaratorButton.setImage(UIImage(named: "add"), forState: UIControlState.Normal)
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
        if done {
            cButton.layer.borderColor = UIColor.greenColor().CGColor
            cButton.layer.borderWidth = 6
        }
        cButton.addTarget(self, action: "collabaratorPressed:", forControlEvents: UIControlEvents.TouchUpInside)
        cView.addSubview(cButton)
        var nameLabel = UILabel(frame: CGRect(x: 0 , y: self.padding + self.imgSize, width: self.imgSize, height: 20))
        nameLabel.font = UIFont.systemFontOfSize(10)
        nameLabel.text = number.contact.name
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        nameLabel.textAlignment = NSTextAlignment.Center
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
        self.contentSize = CGSize(width: self.contentSize() , height: self.bounds.height)
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

class ReminderViewController: StaticDataTableViewController,UITextViewDelegate,CollabaratorViewDelegate,UIActionSheetDelegate{
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    @IBOutlet weak var collaboratorsView: CollabaratorView!
    
    @IBOutlet weak var taskTextView: UITextView!
    
    @IBOutlet weak var dueDateLabel: UILabel!
    
    @IBOutlet weak var dueDateSwitchAdmin: UISwitch!
    @IBOutlet weak var dueDateLabelAdmin: UILabel!
    @IBOutlet weak var dueDatePickerAdmin: UIDatePicker!
    
    
    @IBOutlet weak var addToMyRemindersSwitch: UISwitch!
    @IBOutlet weak var remindMeOnADaySwitch: UISwitch!
    @IBOutlet weak var remindMeAlarmDateLabel: UILabel!
    @IBOutlet weak var remindMeDatePicker: UIDatePicker!
    
    
    @IBOutlet weak var dueDateCell: UITableViewCell!
    
    @IBOutlet weak var dueDateSwitchAdminCell: UITableViewCell!
    @IBOutlet weak var dueDateLabelAdminCell: UITableViewCell!
    @IBOutlet weak var dueDatePickerAdminCell: UITableViewCell!
    
    @IBOutlet weak var remindMeOnADayCell: UITableViewCell!
    @IBOutlet weak var remindMeAlarmDateLabelCell: UITableViewCell!
    @IBOutlet weak var remindMeDatePickerCell: UITableViewCell!
    
    
    
    let dateFormatter = NSDateFormatter()
    var contactsHelper = ContactsHelper.sharedInstance
    var reminder: Reminder!
    var collaborators:[String] = []
    var selectedCollaboratorIndex: Int!
    
    var defaulImage = UIImage(named: "default-avatar")
    
    override func viewDidLoad() {
        //super.viewDidLoad()
        
        let tap = UITapGestureRecognizer(target: self, action:"touchOutside:")
        tap.cancelsTouchesInView = false
        self.tableView.addGestureRecognizer(tap)
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
        let currentDate = NSDate()
        
        self.dueDateLabelAdmin.text = dateFormatter.stringFromDate(currentDate)
        //self.dueDatePickerAdmin.minimumDate = currentDate
        
        self.remindMeAlarmDateLabel.text = dateFormatter.stringFromDate(currentDate)
        //self.remindMeDatePicker.minimumDate = currentDate
        
        
        self.collaboratorsView.collabaratorDelegate = self
        
        self.hideSectionsWithHiddenRows = true
        self.insertTableViewRowAnimation = UITableViewRowAnimation.Top
        self.deleteTableViewRowAnimation = UITableViewRowAnimation.Automatic
        
        self.showReminder()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reminderChangedNotificationReceived:", name: KRemindersChangedNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
    }
    
    func showReminder(){
        //collaborators
        self.collaboratorsView.removeAll()
        
        if !self.reminder.isCurrentUserAdmin() {
            self.collaboratorsView.addCollabaratorButton.hidden = true
        }
        
        if let collaborators = self.reminder.collaborators  {
            for collaborator in collaborators {
                var number = self.contactsHelper.getContactNumberForUserId(collaborator)
                self.collaborators.append(number.userId!)
                self.collaboratorsView.addCollabarator(number, done: self.reminder.isUserDone(number.userId))
            }
        }
        
        //title
        if self.reminder.title.isEmpty {
            self.taskTextView.text = ""
            self.saveButton.enabled = false
        } else {
            self.taskTextView.text = self.reminder.title
        }
        self.taskTextView.editable = self.reminder.isCurrentUserAdmin()
        
        
        //due date
        let isAdmin = self.reminder.isCurrentUserAdmin()
        
        self.cell(self.dueDateCell, setHidden:isAdmin)
        
        self.cell(self.dueDateSwitchAdminCell, setHidden: !isAdmin)
        self.cell(self.dueDateLabelAdminCell, setHidden: true)
        self.cell(self.dueDatePickerAdminCell, setHidden: true)
        
        if let dueDate = self.reminder.dueDate{
            self.dueDateLabel.text = dateFormatter.stringFromDate(dueDate)
            self.dueDateSwitchAdmin.setOn(true, animated: true)
            self.dueDateLabelAdmin.text = dateFormatter.stringFromDate(dueDate)
            self.cell(self.dueDateLabelAdminCell, setHidden: false | !isAdmin)
            self.dueDatePickerAdmin.date = dueDate
        }else{
            self.cell(self.dueDateCell, setHidden:true)
        }
        
        var isOnMyReminders = false
        var isAlarmSet = false
        //remind me
        if self.reminder.objectId != nil {
            isOnMyReminders = UDOReminderManager.sharedInstance.isReminderOnCalendar(self.reminder)
            if isOnMyReminders {
                var alarmDate = UDOReminderManager.sharedInstance.getAlarmDateForReminder(self.reminder)
                if alarmDate == nil {
                    if reminder.dueDate != nil{
                        alarmDate = reminder.dueDate
                    }else {
                        alarmDate = NSDate()
                    }
                    isAlarmSet = false
                }else {
                    isAlarmSet = true
                }
                self.remindMeAlarmDateLabel.text = dateFormatter.stringFromDate(alarmDate)
                self.remindMeDatePicker.date = alarmDate
            }
        }
        self.addToMyRemindersSwitch.setOn(isOnMyReminders, animated: true)
        self.remindMeOnADaySwitch.setOn(isAlarmSet, animated: true)
        self.cell(self.remindMeOnADayCell, setHidden: !isOnMyReminders)
        self.cell(self.remindMeAlarmDateLabelCell, setHidden: !isAlarmSet)
        self.cell(self.remindMeDatePickerCell, setHidden: true)
        
        self.reloadDataAnimated(false)
        
    }
    
    func reminderChangedNotificationReceived(notification: NSNotification){
        if self.reminder.objectId == nil {
            return
        }
        let newReminders = notification.object as [Reminder]
        for newReminder in newReminders {
            if (newReminder.objectId == self.reminder.objectId && newReminder.updatedAt.compare(self.reminder.updatedAt) == NSComparisonResult.OrderedDescending ){
                self.reminder = newReminder
                self.showReminder()
            }
        }
    }
    
    func addCollabaratorButtonPressed(){
        self.performSegueWithIdentifier("SelectContact", sender: nil)
    }
    func collabaratorSelected(index:Int){
        //todo
        if self.reminder.isCurrentUserAdmin() && self.collaborators[index] != PFUser.currentUser().username {
            self.selectedCollaboratorIndex = index
            let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: nil, destructiveButtonTitle: "Remove User", otherButtonTitles: "Cancel")
            actionSheet.cancelButtonIndex = 1
            actionSheet.showInView(self.view)
        }
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int){
        if buttonIndex == 0 {
            self.collaborators.removeAtIndex(self.selectedCollaboratorIndex)
            self.collaboratorsView.removeCollabaratorAtIndex(self.selectedCollaboratorIndex)
        }
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
            UDOReminderManager.sharedInstance.requestAccess({ (success:Bool, _) -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if success {
                        self.cell(self.remindMeOnADayCell, setHidden: !sender.on)
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
            self.cell(self.remindMeAlarmDateLabelCell, setHidden: !sender.on)
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
        }else if self.remindMeDatePicker == sender {
            self.remindMeAlarmDateLabel.text = dateFormatter.stringFromDate(sender.date)
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 3 && indexPath.row == 1 {
            let hidden = !self.cellIsHidden(self.dueDatePickerAdminCell)
            self.cell(self.dueDatePickerAdminCell, setHidden: hidden)
            self.reloadDataAnimated(true)
            if !self.cellIsHidden(self.dueDatePickerAdminCell) {
                var indexPath = self.tableView.indexPathForCell(self.dueDatePickerAdminCell)
                self.tableView.scrollToRowAtIndexPath(indexPath!, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
            }
        }else if indexPath.section == 4 && indexPath.row == 2 {
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
    
}
