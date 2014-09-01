//
//  ReminderItemCell.swift
//  udo
//
//  Created by Osman Alpay on 27/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class ReminderItemTableViewCell: UITableViewCell {
    @IBOutlet weak var itemTextView : UITextView!
    @IBOutlet weak var checkButton: UIButton!
    @IBOutlet weak var alarmDateLabel: UILabel!
    @IBOutlet weak var reminderNameLabel: UILabel!
    @IBOutlet weak var itemTextBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var itemTextTopSpace: NSLayoutConstraint!
    let dateFormatter = NSDateFormatter()
    
    var maskLayer:CAShapeLayer!
    
    func initForSearchResults(reminderTask:NSDictionary!){
        initTaskCell(reminderTask)
        self.reminderNameLabel.text = reminderTask["reminderName"] as String
        self.itemTextView.userInteractionEnabled = false
    }
    
    func initForReminderCard(reminderTask:NSDictionary!){
        initTaskCell(reminderTask)
        self.reminderNameLabel.hidden = true
        self.itemTextTopSpace.constant = 0
        self.itemTextView.userInteractionEnabled = true
    }
    
    
    func initMaskLayer(size:CGSize){
        maskLayer = CAShapeLayer()
        let maskRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        maskLayer.path = CGPathCreateWithRect(maskRect, nil)
        self.layer.mask = maskLayer
    }
    
    func initTaskCell(reminderTask:NSDictionary!){
         self.itemTextView.scrollEnabled = false
        itemTextView.text = reminderTask[kReminderItemDescription] as String
        let status = reminderTask[kReminderItemStatus] as Int
        checkButton.hidden = (status != ReminderTaskStatus.Done.toRaw())
        
        dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        
        let alarmDate = reminderTask["alarmDate"] as  NSDate
        if NSDate(timeIntervalSince1970: 0) != alarmDate{
            alarmDateLabel.text = dateFormatter.stringFromDate(alarmDate)
        }else{
            alarmDateLabel.hidden = true
        }
    }
    
    
    func maskOffset(maskOffset:CGFloat){
        self.maskLayer.frame.origin.y = maskOffset
    }
    
    func cellHeightThatFitsForItemText(itemText:String) -> CGFloat{
        self.itemTextView.text = itemText
        var sizeThatFits = self.itemTextView.frame.size
        sizeThatFits = self.itemTextView.sizeThatFits(sizeThatFits)
        return self.itemTextTopSpace.constant + self.itemTextBottomSpace.constant + sizeThatFits.height
    }
    
}

