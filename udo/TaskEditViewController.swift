//
//  TaskEditViewController.swift
//  udo
//
//  Created by Osman Alpay on 06/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class TaskEditViewController: UITableViewController,UITextViewDelegate{
    
    @IBOutlet weak var actionButton: UIBarButtonItem!
    @IBOutlet weak var taskTextView: UITextView!
    @IBOutlet weak var alarmLabel: UILabel!
    @IBOutlet weak var remindSwitch: UISwitch!
    @IBOutlet weak var datePicker: UIDatePicker!
    let dateFormatter = NSDateFormatter()
    
    var item: NSDictionary!
    
    override func viewDidLoad() {
        let tap = UITapGestureRecognizer(target: self, action:"touchOutside:")
        tap.cancelsTouchesInView = false
        self.tableView.addGestureRecognizer(tap)
        dateFormatter.locale = NSLocale.currentLocale()
        dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        let currentDate = NSDate()
        alarmLabel.text = dateFormatter.stringFromDate(currentDate)
        datePicker.minimumDate = currentDate
        
        taskTextView.text = item[kReminderItemDescription] as String
        let alarmDate = item[kReminderItemAlarmDate] as NSDate
        if alarmDate != NSDate(timeIntervalSince1970: 0){
            remindSwitch.on = true
            alarmLabel.text = dateFormatter.stringFromDate(alarmDate)
            datePicker.date = alarmDate
        }
    }
    
    func touchOutside(sender:UITapGestureRecognizer) {
        self.taskTextView.endEditing(false)
    }
    
    
    @IBAction func remindSwitchChanged(sender: AnyObject) {
        self.tableView.beginUpdates()
        if(remindSwitch.on){
            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 1, inSection: 1),NSIndexPath(forRow: 2, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Automatic)
        }else{
            self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: 1, inSection: 1),NSIndexPath(forRow: 2, inSection: 1)], withRowAnimation:  UITableViewRowAnimation.Automatic)
        }
        self.tableView.endUpdates()
    }
    
    func textViewDidChange(textView: UITextView!) {
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
    }
    
    @IBAction func dateChanged(sender: UIDatePicker) {
        print(dateFormatter.stringFromDate(sender.date))
        self.alarmLabel.text = dateFormatter.stringFromDate(sender.date)
    }
    
    
    
    override func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if indexPath.section == 0 {
            self.taskTextView.layoutIfNeeded()
            var sizeThatFits = self.taskTextView.frame.size
            sizeThatFits.width = self.tableView.frame.size.width - 16 //margins
            sizeThatFits = self.taskTextView.sizeThatFits(sizeThatFits)
            return max(44,sizeThatFits.height + 16/*margins*/)
        }
        return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
    }
    
    override func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        if section == 1 && !remindSwitch.on {
            // reminder is off
            return 1
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
}
