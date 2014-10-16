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


var RightArrowImage = UIImage(named: "right").imageTintedWithColor(AppTheme.iconMaskColor)
var LeftArrowImage = UIImage(named: "left").imageTintedWithColor(AppTheme.iconMaskColor)

var CalendarImage = UIImage(named: "calendar").imageTintedWithColor(AppTheme.iconMaskColor)
var NotificationImage = UIImage(named: "notifications").imageTintedWithColor(AppTheme.iconMaskColor)


class ReminderItemTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel : UILabel!
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var dueDateLabel: UILabel!
    @IBOutlet weak var alarmDateLabel: UILabel!
    @IBOutlet weak var reminderNameLabel: UILabel!
    @IBOutlet weak var errorMsgLabel: UILabel!
    @IBOutlet weak var calendarIconView: UIImageView!
    @IBOutlet weak var alarmIconView: UIImageView!
    @IBOutlet weak var directionImageView: UIImageView!
    
    private let dateFormatter = NSDateFormatter()
    
    private var contactsManager = ContactsManager.sharedInstance
    private var reminderManager = ReminderManager.sharedInstance
    private var eventStoreManager = EventStoreManager.sharedInstance
    
    private var statusPresedGesture:UITapGestureRecognizer!
    private var statusLayer:CAShapeLayer!
    private var statusRatioLayer:CAShapeLayer!
    private var doneLayer:CAShapeLayer!
    
    private var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
    
    var reminderKey:String!
    private var reminder:Reminder!
    
    private var ratio = 0.0
    
    override func awakeFromNib() {
        self.calendarIconView.image = CalendarImage
        self.alarmIconView.image = NotificationImage
        
        self.statusPresedGesture = UITapGestureRecognizer(target: self, action: "statusPressed:")
        self.statusView.addGestureRecognizer(statusPresedGesture)
        self.statusView.backgroundColor = UIColor.clearColor()
        
        self.statusLayer = self.statusLayer( inner: false, strokeColor: AppTheme.doneRingBackgroudColor.CGColor)
        self.statusView.layer.addSublayer(self.statusLayer)
        
        self.doneLayer = self.statusLayer( inner: true, strokeColor: AppTheme.doneColor.CGColor)
        self.doneLayer.hidden = true
        self.statusView.layer.addSublayer(self.doneLayer)
        
        self.statusRatioLayer = self.statusLayer( inner: false, strokeColor: AppTheme.doneRingForegroundColor.CGColor)
        self.statusRatioLayer.strokeEnd = 0.0
        self.statusView.layer.addSublayer(self.statusRatioLayer)
        
        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.center = self.statusView.center
        statusView.addSubview(self.activityIndicator)
        
        self.titleLabel.textColor = AppTheme.reminderTitleColor
        self.reminderNameLabel.textColor = AppTheme.reminderHeaderColor
    }
    
    override func prepareForReuse() {
        self.hideActivity()
        self.errorMsgLabel.text = ""
        self.dueDateLabel.hidden = false
        self.calendarIconView.hidden = false
        self.alarmDateLabel.hidden = false
        self.alarmIconView.hidden = false
        self.doneLayer.hidden = true
        self.reminder = nil
        self.ratio = 0
    }
    
    func statusPressed(sender: AnyObject){
        if self.reminderManager.isReminderLoadingWithKey(self.reminder.key()) {
            return
        }
        // save status before save
        var isUserDone = self.reminder.isCurrentUserDone()
        if !reminder.isDirty() {
            if isUserDone {
                self.reminder.setUserUnDone()
            } else {
                self.reminder.setUserDone()
            }
            self.reminderManager.saveReminder(self.reminder, resultBlock: nil)
        }
    }
    
    func updateActivity(){
        if self.reminderManager.isReminderLoadingWithKey(self.reminder.key()){
           self.showActivity()
        }else{
          self.hideActivity()
        }
    }
    
    func showActivity(){
        self.doneLayer.hidden = true
        self.activityIndicator.startAnimating()
    }
    
    func hideActivity(){
        self.activityIndicator.stopAnimating()
        if reminder.isUserDone(PFUser.currentUser().username) {
            self.doneLayer.hidden = false
        }else{
            self.doneLayer.hidden = true
        }
    }
    
    func updateErrorMsg(){
        if self.reminderManager.isThereErrorForKey(self.reminder.key()) {
             self.errorMsgLabel.text = "Failed to save!"
        }else {
            self.errorMsgLabel.text = ""
        }
    }
    
    func updateTitle(){
        if self.reminder.isCurrentUserAdmin() {
            self.directionImageView.image = RightArrowImage
        }else {
            self.directionImageView.image = LeftArrowImage
        }
        var title = ""
        for collaborator in reminder.getOthers() {
            if title != "" {
                title += ", "
            }
            var number = self.contactsManager.getContactNumberForUserId(collaborator)
            if let name = number.contact.name {
                title += name
            }else{
                 title += number.userId
            }
            
        }
        self.reminderNameLabel.text = title
    }
    
    func updateStatus(){
        if reminder.isUserDone(PFUser.currentUser().username) {
            self.doneLayer.hidden = false
        }else{
            self.doneLayer.hidden = true
        }
        self.changeDoneRatio(self.reminder.doneRatio())
    }
    
    func updateAlaramLabels(){
        var now = NSDate()
        if let alarmDate = self.eventStoreManager.getAlarmDateForKey(reminder.key()){
            var  prettyDate = MHPrettyDate.prettyDateFromDate(alarmDate, withFormat: MHPrettyDateFormatWithTime)
            self.alarmDateLabel.text = prettyDate
            self.alarmDateLabel.hidden = false
            self.alarmIconView.hidden = false
            if alarmDate.laterDate(now) == alarmDate || self.reminder.isCurrentUserDone() {
                self.alarmDateLabel.textColor = AppTheme.dateTimeColor
            }else{
                self.alarmDateLabel.textColor = AppTheme.dateTimeWarningColor
            }
        }else{
            self.alarmDateLabel.hidden = true
            self.alarmIconView.hidden = true
        }

    }
    
    func updateCalendarLabels(){
        var now = NSDate()
        if let dueDate = reminder.dueDate {
            var  prettyDate = MHPrettyDate.prettyDateFromDate(dueDate, withFormat: MHPrettyDateFormatWithTime)
            self.dueDateLabel.text = prettyDate
            self.dueDateLabel.hidden = false
            self.calendarIconView.hidden = false
            if dueDate.laterDate(now) == dueDate || self.reminder.isCurrentUserDone() {
                self.dueDateLabel.textColor = AppTheme.dateTimeColor
            }else{
                self.dueDateLabel.textColor = AppTheme.dateTimeWarningColor
            }
        }else{
            self.dueDateLabel.hidden = true
            self.calendarIconView.hidden = true
        }
        
    }
    
    func updateAll(){
        self.reminder = self.reminderManager.getReminder(self.reminderKey)
        self.titleLabel.text = reminder.title
        self.updateAlaramLabels()
        self.updateCalendarLabels()
        self.updateTitle()
        self.updateErrorMsg()
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
            circle.fillColor = strokeColor
        }else{
            circle.fillColor = UIColor.clearColor().CGColor
        }
        circle.strokeColor = strokeColor
        circle.lineWidth = 5
        return circle
    }
    
    func changeDoneRatio(ratio:Double){
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

