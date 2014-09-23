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
    
    let RadioImageChecked = ReminderItemTableViewCell.getRadioImage(true)
    let RadioImageUnChecked = ReminderItemTableViewCell.getRadioImage(false)
    
    override func awakeFromNib() {
        self.checkButton.backgroundColor = UIColor.clearColor()
        self.checkButton.setBackgroundImage(self.RadioImageUnChecked, forState: UIControlState.Normal)
    }
    
    override func prepareForReuse() {
        alarmDateLabel.hidden = false
        checkButton.setBackgroundImage(self.RadioImageUnChecked, forState: UIControlState.Normal)
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
            checkButton.setBackgroundImage(self.RadioImageChecked, forState: UIControlState.Normal)
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
    
    
    class func getRadioImage(isChecked:Bool) -> UIImage{
        let size = 200.0
        let outherInset = 20.0
        let innerInset = 35.0

        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0.0)
        let context = UIGraphicsGetCurrentContext();
        UIGraphicsPushContext(context);
        CGContextSetRGBStrokeColor(context, 0.0, 0.0, 0.0, 0.7);
        CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 0.7);
        //CGContextSetShadow(context, CGSizeZero, 10)
        CGContextSetAllowsAntialiasing(context, true)
        CGContextSetShouldAntialias(context, true)
        
        var outherRect = CGRect(x: outherInset, y: outherInset, width: size - 2 * outherInset , height: size - 2 * outherInset)
        var outherPath = UIBezierPath(ovalInRect: outherRect)
        outherPath.lineWidth = 10
        outherPath.stroke()
        
        if isChecked {
            var innerRect = CGRect(x: innerInset, y: innerInset, width: size - 2 * innerInset , height: size - 2 * innerInset)
            var innerPath = UIBezierPath(ovalInRect: innerRect)
            innerPath.fill()
        }
        
        UIGraphicsPopContext();
        let outputImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return outputImage
    }
    
}

