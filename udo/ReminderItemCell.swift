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

var RightArrowImage = UIImage(named: "right")?.imageTintedWithColor(AppTheme.iconMaskColor)
var LeftArrowImage = UIImage(named: "left")?.imageTintedWithColor(AppTheme.iconMaskColor)

var CalendarActiveImage = UIImage(named: "calendar")?.imageTintedWithColor(AppTheme.iconMaskColor)
var CalendarPassiveImage = UIImage(named: "calendar")?.imageTintedWithColor(AppTheme.iconPassiveMaskColor)

var AlarmActiveImage = UIImage(named: "notifications")?.imageTintedWithColor(AppTheme.iconMaskColor)
var AlarmPassiveImage = UIImage(named: "notifications")?.imageTintedWithColor(AppTheme.iconPassiveMaskColor)

var RetryImage = UIImage(named: "redo")?.imageTintedWithColor(AppTheme.tintColor)

var RepeatImage = UIImage(named: "redo")?.imageTintedWithColor( UIColor.grayColor())


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
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var retryImageView: UIImageView!
    @IBOutlet weak var dueDateRepeatIconImage: UIImageView!
    
    @IBOutlet weak var badgeView: UDBadgeLabel!
    
    private let dateFormatter = NSDateFormatter()
    
    private var contactsManager = ContactsManager.sharedInstance
    private var reminderManager = ReminderManager.sharedInstance
    
    private var statusPresedGesture:UITapGestureRecognizer!
    private var statusLayer:CAShapeLayer!
    var statusRatioLayer:CAShapeLayer!
    var doneLayer:CAShapeLayer!
    
    
    var reminderKey:String!
    private var reminder:Reminder!
    
    private var ratio = 0.0
    
    let defaultSeparatorColor = UIColor(red: 200, green: 199, blue: 204, alpha: 1)
    
    override func awakeFromNib() {
        self.contentView.backgroundColor = AppTheme.reminderCellNormalColor
        self.calendarIconView.image = CalendarPassiveImage
        
        self.alarmIconView.image = AlarmPassiveImage
        self.alarmDateLabel.textColor = AppTheme.dateTimeColor
        
        // for fixing the background color leak before the separator
        let whitePatchLayer = CALayer()
        whitePatchLayer.frame = CGRect(x: 0, y: 0, width: 50, height: 70)
        whitePatchLayer.backgroundColor = UIColor.whiteColor().CGColor
        self.contentView.layer.insertSublayer(whitePatchLayer, below:  self.statusView.layer)
        
        self.statusPresedGesture = UITapGestureRecognizer(target: self, action: "statusPressed:")
        self.statusView.addGestureRecognizer(statusPresedGesture)
        self.statusView.backgroundColor = UIColor.clearColor()
        
        self.statusLayer = self.statusLayer( inner: false, strokeColor: AppTheme.doneRingBackgroudColor.CGColor)
        self.statusView.layer.addSublayer(self.statusLayer)
        
        self.doneLayer = self.statusLayer( inner: true, strokeColor: AppTheme.doneColor.CGColor)
        self.doneLayer.hidden = true
        self.statusView.layer.addSublayer(self.doneLayer)
        
        self.retryImageView.image = RetryImage
        
        self.dueDateRepeatIconImage.image = RepeatImage
        
        self.statusRatioLayer = self.statusLayer( inner: false, strokeColor: AppTheme.doneRingForegroundColor.CGColor)
        self.statusRatioLayer.strokeEnd = 0.0
        self.statusView.layer.addSublayer(self.statusRatioLayer)
        
        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        
        self.activityIndicator.hidesWhenStopped = true
        
        self.titleLabel.textColor = AppTheme.reminderTitleColor
        self.reminderNameLabel.textColor = AppTheme.reminderHeaderColor
        
        self.badgeView.text = "0"
    }
    
    override func prepareForReuse() {
        self.activityIndicator.stopAnimating()
        self.retryImageView.hidden = true
        self.errorMsgLabel.text = ""
        self.dueDateLabel.hidden = false
        self.calendarIconView.hidden = false
        self.alarmDateLabel.hidden = false
        self.alarmIconView.hidden = false
        self.doneLayer.hidden = true
        self.reminder = nil
        self.setDoneRatio(0, animated: false)
    }
    
    func statusPressed(sender: AnyObject){
        if ( self.reminderManager.isReminderLoadingWithKey(self.reminderKey)) {
            return
        }
        if self.reminderManager.isThereErrorForKey(self.reminder.key()){
            //retry
            self.reminderManager.retrySaving(self.reminder.key())
        }else{
            var isUserDone = self.reminder.isCurrentUserDone()
            self.reminderManager.changeReminderStatusForCurrentUser(self.reminderKey, done: !isUserDone, resultBlock: nil)
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
            if let udContact = self.contactsManager.getUDContactForUserId(collaborator){
                title += udContact.name()
            }
        }
        self.reminderNameLabel.text = title
    }
    
    func updateStatusView(){
        let isLoading = self.reminderManager.isReminderLoadingWithKey(self.reminderKey)
        if isLoading {
            self.activityIndicator.startAnimating()
        }else{
            self.activityIndicator.stopAnimating()
        }
        self.setDoneRatio(self.reminder.doneRatio(),animated:true)
        if isLoading || self.reminder.failedToSave || !self.reminder.isCurrentUserDone(){
            self.doneLayer.hidden = true
        }else {
            self.doneLayer.hidden = false
        }
        if self.reminder.failedToSave {
            self.errorMsgLabel.text = "Failed to save!"
            self.retryImageView.hidden = false
        }else{
            self.retryImageView.hidden = true
            self.errorMsgLabel.text = ""
        }
    }
    
    
    func updateAlaramLabels(){
        var now = NSDate()
        if let alarmDate = self.reminder.alarmDate {
            var  prettyDate = MHPrettyDate.prettyDateFromDate(alarmDate, withFormat: MHPrettyDateFormatWithTime)
            self.alarmDateLabel.text = prettyDate
            self.alarmDateLabel.hidden = false
            self.alarmIconView.hidden = false
            if alarmDate.laterDate(now) == alarmDate {
                self.alarmIconView.image = AlarmActiveImage
            }else{
                self.alarmIconView.image = AlarmPassiveImage
            }
        }else{
            self.alarmDateLabel.hidden = true
            self.alarmIconView.hidden = true
        }
        
    }
    
    func updateCalendarLabels(){
        var now = NSDate()
        self.dueDateRepeatIconImage.hidden = true
        if let dueDate = reminder.dueDate {
            //var prettyDate = MHPrettyDate.prettyDateFromDate(dueDate, withFormat: MHPrettyDateFormatWithTime, withDateStyle: NSDateFormatterStyle.FullStyle, withTimeStyle: NSDateFormatterStyle.FullStyle)
            var  prettyDate = MHPrettyDate.prettyDateFromDate(dueDate, withFormat: MHPrettyDateFormatWithTime)
            self.dueDateLabel.text = prettyDate
            self.dueDateLabel.hidden = false
            self.calendarIconView.hidden = false
            if dueDate.laterDate(now) == dueDate || self.reminder.isCurrentUserDone() {
                self.dueDateLabel.textColor = AppTheme.dateTimeColor
            }else{
                self.dueDateLabel.textColor = AppTheme.dateTimeWarningColor
            }
            if self.reminder.dueDateInterval != nil {
                self.dueDateRepeatIconImage.hidden = false
            }
            if self.reminder.isCurrentUserDone() {
                self.calendarIconView.image = CalendarPassiveImage
            }else {
                self.calendarIconView.image = CalendarActiveImage
            }
        }else{
            self.dueDateLabel.hidden = true
            self.calendarIconView.hidden = true
        }
    }
    
    func updateNotesBadge(){
       let unreadCount = self.reminderManager.getReminderNotes(self.reminderKey).getUnreadMessageCount()
        if unreadCount > 0 {
            self.badgeView.hidden = false
            self.badgeView.text = "\(unreadCount)"
        }else {
            self.badgeView.hidden = true
        }
    }
    
    
    func setAccessoryColorForState(state:ReminderState){
        switch state {
        case .ReceivedNew:
            self.accessoryView = MSCellAccessory(type: FLAT_DISCLOSURE_INDICATOR, color: UIColor.whiteColor())
            self.backgroundColor = AppTheme.reminderCellNewColor
        case .Seen:
            if let dueDate = reminder.dueDate {
                if dueDate.earlierDate(NSDate()) == dueDate {
                    if !reminder.isCurrentUserDone() {
                        self.accessoryView = MSCellAccessory(type: FLAT_DISCLOSURE_INDICATOR, color: UIColor.whiteColor())
                         self.backgroundColor = AppTheme.reminderCellOverdueColor
                        break
                    }
                }
            }
            self.accessoryView = MSCellAccessory(type: FLAT_DISCLOSURE_INDICATOR, color: AppTheme.doneRingBackgroudColor)
            self.backgroundColor = AppTheme.reminderCellNormalColor

        case .ReceivedUpdated:
            self.accessoryView = MSCellAccessory(type: FLAT_DISCLOSURE_INDICATOR, color: UIColor.whiteColor())
            self.backgroundColor = AppTheme.reminderCellUnSeenColor
        default:
            self.accessoryView = MSCellAccessory(type: FLAT_DISCLOSURE_INDICATOR, color: AppTheme.doneRingBackgroudColor)
            self.backgroundColor = AppTheme.reminderCellNormalColor
        }
        self.accessoryView?.frame.size.width = 18
    }

    
    func updateAll(){
        self.reminder = self.reminderManager.getReminder(self.reminderKey)
        self.titleLabel.text = reminder.title
        self.updateAlaramLabels()
        self.updateCalendarLabels()
        self.updateTitle()
        self.updateStatusView()
        self.updateNotesBadge()
    }
    
    func statusLayer(#inner:Bool, strokeColor:CGColor) -> CAShapeLayer {
        // Set up the shape of the circle
        var circle = CAShapeLayer()
        var size = self.statusView.frame.size
        var radius:CGFloat!
        var margin:CGFloat!
        if inner {
            margin = 16.0
            radius = size.width - margin*2
        }else{
            margin = 8.0
            radius = size.width - margin*2
        }
        var rect = CGRect(x: margin, y: margin, width: radius, height: radius )
        var path = UIBezierPath(roundedRect: rect, cornerRadius: radius / 2)
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
    
    func setDoneRatio(ratio:Double,animated:Bool){
        if ratio == self.ratio {
            return
        }
        self.statusRatioLayer.strokeEnd = CGFloat(ratio)
        var animation = CABasicAnimation(keyPath: "strokeEnd")
        if animated {
            animation.duration = 1.0}
        else{
            animation.duration = 0
        }
        animation.fromValue = self.ratio
        animation.toValue = ratio
        animation.removedOnCompletion = true
        self.statusRatioLayer.addAnimation(animation, forKey: "ratio")
        self.ratio = ratio
    }
}

