//
//  ReminderItemCell.swift
//  udo
//
//  Created by Osman Alpay on 27/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

let itemDoneImage = UIImage(named: "checkmark")
let itemPendingImage = UIImage(named: "checkmark_empty")

class ReminderItemTableViewCell: UITableViewCell {
    @IBOutlet weak var itemTextView : UITextView!
    @IBOutlet weak var checkButton: UIButton!
    @IBOutlet weak var alarmDateLabel: UILabel!
    @IBOutlet weak var reminderNameLabel: UILabel!
    @IBOutlet weak var itemTextBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var itemTextTopSpace: NSLayoutConstraint!
    let dateFormatter = NSDateFormatter()
    
    var maskLayer:CAShapeLayer!
    
    override func prepareForReuse() {
        alarmDateLabel.hidden = false
        checkButton.setBackgroundImage(itemPendingImage, forState: UIControlState.Normal)
    }
    
    func initForSearchResults(reminderTask:NSDictionary!){
        initTaskCell(reminderTask)
        self.reminderNameLabel.text = reminderTask["reminderName"] as? String
        self.itemTextView.userInteractionEnabled = false
    }
    
    func initForReminderCard(reminderTask:NSDictionary!){
        initTaskCell(reminderTask)
        self.reminderNameLabel.hidden = true
        self.itemTextTopSpace.constant = 0
    }
    

    func initTaskCell(item:NSDictionary!){
         self.itemTextView.scrollEnabled = false
        itemTextView.text = item[kReminderItemDescription] as String
        let status = item[kReminderItemStatus] as Int
        if status == ReminderTaskStatus.Done.toRaw(){
            checkButton.setBackgroundImage(itemDoneImage, forState: UIControlState.Normal)
        }
        dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        
        let alarmDate = item[kReminderItemAlarmDate] as  NSDate
        if NSDate(timeIntervalSince1970: 0) != alarmDate{
            alarmDateLabel.text = dateFormatter.stringFromDate(alarmDate)
        }else{
            alarmDateLabel.hidden = true
        }
    }

    func cellHeightThatFitsForItemText(itemText:String) -> CGFloat{
        self.itemTextView.text = itemText
        var sizeThatFits = self.itemTextView.frame.size
        sizeThatFits.width -= 8 //some mysterious margin
        sizeThatFits = self.itemTextView.sizeThatFits(sizeThatFits)
        return self.itemTextTopSpace.constant + self.itemTextBottomSpace.constant + sizeThatFits.height + 1
    }
    
}

