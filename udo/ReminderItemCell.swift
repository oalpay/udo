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
    @IBOutlet weak var titleLabel : UILabel!
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var dueDateLabel: UILabel!
    @IBOutlet weak var alarmDateLabel: UILabel!
    @IBOutlet weak var reminderNameLabel: UILabel!

    
    let dateFormatter = NSDateFormatter()
    
    var contactsHelper = ContactsHelper.sharedInstance
    
    var statusPresedGesture:UITapGestureRecognizer!
    var statusLayer:CAShapeLayer!
    var statusRatioLayer:CAShapeLayer!
    var doneLayer:CAShapeLayer!
    
    var reminder:Reminder!
    
    var isSaving = false
    
    var ratio = 0.0
    
    override func awakeFromNib() {
        statusPresedGesture = UITapGestureRecognizer(target: self, action: "statusPressed:")
        self.statusView.addGestureRecognizer(statusPresedGesture)
        self.statusView.backgroundColor = UIColor.clearColor()

        self.statusLayer = self.statusLayer( inner: false, strokeColor: UIColor.lightGrayColor().CGColor)
        self.statusView.layer.addSublayer(self.statusLayer)
        
        self.doneLayer = self.statusLayer( inner: true, strokeColor: UIColor.darkGrayColor().CGColor)
        self.doneLayer.hidden = true
        self.statusView.layer.addSublayer(self.doneLayer)
        
        self.statusRatioLayer = self.statusLayer( inner: false, strokeColor: UIColor.darkGrayColor().CGColor)
        self.statusRatioLayer.strokeEnd = 0.0
        self.statusView.layer.addSublayer(self.statusRatioLayer)
        
        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
    }
    
    override func prepareForReuse() {
        self.dueDateLabel.hidden = false
        self.alarmDateLabel.hidden = false
        self.doneLayer.hidden = true
        self.reminder = nil
        self.ratio = 0
    }
    
    func statusPressed(sender: AnyObject){
        if self.isSaving {
            return
        }
        self.isSaving = true
        if self.reminder.isCurrentUserDone() {
            self.reminder.removeObject(PFUser.currentUser().username, forKey: kReminderDones)
        } else {
            self.reminder.addObject(PFUser.currentUser().username, forKey: kReminderDones)
        }
        self.updateStatus()
        self.reminder.saveEventually { (success:Bool, error:NSError!) -> Void in
            self.isSaving = false
            if error != nil {
                self.updateStatus()
                println("e:statusPressed:\(error.description)")
                UIAlertView(title: "Error", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "Ok").show()
            }
        }
    }
    
    func updateStatus(){
        if reminder.isUserDone(PFUser.currentUser().username) {
            self.doneLayer.hidden = false
            self.animateDoneRatio(self.reminder.doneRatio())
        }else{
            self.doneLayer.hidden = true
            self.animateDoneRatio(self.reminder.doneRatio())
        }
    }
    
    
    func setReminder(reminder:Reminder!){
        self.reminder = reminder
        self.titleLabel.text = reminder.title
        if let dueDate = reminder.dueDate {
            var  prettyDate = MHPrettyDate.prettyDateFromDate(dueDate, withFormat: MHPrettyDateFormatWithTime)
            dueDateLabel.text = "Due \(prettyDate)"
        }else{
            dueDateLabel.hidden = true
        }
        if let alarmDate = UDOReminderManager.sharedInstance.getAlarmDateForReminder(reminder){
            var  prettyDate = MHPrettyDate.prettyDateFromDate(alarmDate, withFormat: MHPrettyDateFormatWithTime)
            alarmDateLabel.text = "Alarm \(prettyDate)"
        }else{
            alarmDateLabel.hidden = true
        }
        var title = ""
        for collaborator in reminder.getOthers() {
            if title != "" {
                title = title + ", "
            }
            title = title + self.contactsHelper.getContactNumberForUserId(collaborator).contact.name
        }
        self.reminderNameLabel.text = title
        self.updateStatus()
    }
    
    
    func statusLayer(#inner:Bool, strokeColor:CGColor) -> CAShapeLayer {
        // Set up the shape of the circle
        var circle = CAShapeLayer()
        var radius:CGFloat!
        if inner {
            radius = 8
        }else{
            radius = 16
        }
        var center = self.statusView.center
        var rect = CGRect(x: center.x - radius , y: center.y - radius, width: 2.0 * radius, height: 2.0 * radius)
        var path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        // Make a circular shape
        circle.path = path.CGPath
        
        // Configure the apperence of the circle
        if inner {
            circle.fillColor = UIColor.darkGrayColor().CGColor
        }else{
            circle.fillColor = UIColor.clearColor().CGColor
        }
        circle.strokeColor = strokeColor
        circle.lineWidth = 5
        return circle
    }
    
    func animateDoneRatio(ratio:Double){
        self.statusRatioLayer.removeAllAnimations()
        self.statusRatioLayer.strokeEnd = CGFloat(ratio)
        var animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = 1.0
        animation.fromValue = self.ratio
        animation.toValue = ratio
        animation.removedOnCompletion = true
        self.statusRatioLayer.addAnimation(animation, forKey: "ratio")
        self.ratio = ratio
    }
    
}

