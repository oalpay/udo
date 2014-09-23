//
//  TaskEditViewController.swift
//  udo
//
//  Created by Osman Alpay on 06/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class TaskEditViewController: UITableViewController,UITextViewDelegate{
    @IBOutlet weak var taskTextView: UITextView!
    @IBOutlet weak var alarmLabel: UILabel!
    @IBOutlet weak var remindSwitch: UISwitch!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var addToRemindersSwitch: UISwitch!

    let dateFormatter = NSDateFormatter()
    
    var card: PFObject!
    var itemIndex: Int!
    var item: NSMutableDictionary!
    
    override func viewDidLoad() {
        let tap = UITapGestureRecognizer(target: self, action:"touchOutside:")
        tap.cancelsTouchesInView = false
        self.tableView.addGestureRecognizer(tap)
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        let currentDate = NSDate()
        self.alarmLabel.text = dateFormatter.stringFromDate(currentDate)
        self.datePicker.minimumDate = currentDate
        
        self.taskTextView.text = item[kReminderItemDescription] as String
        let alarmDate = item[kReminderItemAlarmDate] as NSDate
        if alarmDate != NSDate(timeIntervalSince1970: 0){
            self.remindSwitch.on = true
            self.alarmLabel.text = dateFormatter.stringFromDate(alarmDate)
            self.datePicker.date = alarmDate
        }
        
        let itemIds = item[kReminderItemCalendarIds] as NSDictionary
        if let itemId = itemIds[PFUser.currentUser().username] as? String {
            if itemId != "0" {
                addToRemindersSwitch.setOn(true, animated: true)
            }
        }
        
    }
    
    func editItem(card:PFObject,itemIndex:Int){
        self.card = card
        self.itemIndex = itemIndex
        let items = card[kReminderCardItems] as [NSMutableDictionary]
        self.item = items[itemIndex]
    }
    
    func touchOutside(sender:UITapGestureRecognizer) {
        self.taskTextView.endEditing(false)
    }
    
    
    @IBAction func saveButtonPressed(sender: AnyObject) {
        item[kReminderItemDescription] = taskTextView.text
        if remindSwitch.on {
            item[kReminderItemAlarmDate] = datePicker.date
        }
        if addToRemindersSwitch.on {
            UDOReminderManager.sharedInstance.addItemToReminders(item)
        }
        self.performSegueWithIdentifier("SaveItemEdit", sender: nil)
    }
    
    @IBAction func remindSwitchChanged(sender: AnyObject) {
        self.tableView.beginUpdates()
        if(remindSwitch.on){
            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 2, inSection: 1),NSIndexPath(forRow: 3, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Automatic)
        }else{
            self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: 2, inSection: 1),NSIndexPath(forRow: 3, inSection: 1)], withRowAnimation:  UITableViewRowAnimation.Automatic)
        }
        self.tableView.endUpdates()
    }
    
    func textViewDidChange(textView: UITextView!) {
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
    }
    
    @IBAction func dateChanged(sender: UIDatePicker) {
        self.alarmLabel.text = dateFormatter.stringFromDate(sender.date)
    }
    
    
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            self.taskTextView.superview?.layoutIfNeeded()
            var sizeThatFits = self.taskTextView.frame.size
            sizeThatFits.width = self.tableView.frame.size.width - 16 //margins
            sizeThatFits = self.taskTextView.sizeThatFits(sizeThatFits)
            return max(44,sizeThatFits.height + 20/*margins*/)
        }
        return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 && !remindSwitch.on {
            return 2
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
}
