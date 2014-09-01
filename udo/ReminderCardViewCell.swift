//
//  ReminderCardViewCell.swift
//  udo
//
//  Created by Osman Alpay on 02/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import UIKit
import QuartzCore
import MessageUI

class ReminderCardViewCell : UICollectionViewCell,UITextViewDelegate,UITableViewDataSource,UITableViewDelegate,UIActionSheetDelegate,MFMessageComposeViewControllerDelegate{
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var contactImage: UIImageView!
    @IBOutlet var cardFrame : UIView!
    @IBOutlet var cardName : UILabel!
    @IBOutlet var cardDetails : UILabel!
    @IBOutlet var tasksTableView : UITableView!
    @IBOutlet var reminderCollectionViewController : RemindersCollectionViewController!
    @IBOutlet weak var cardActionButton: UIButton!
    @IBOutlet weak var invitationImage: UIImageView!
    
    var ownerContact:Contact!
    var reminderCard:PFObject!
    var cardItems:[NSMutableDictionary] = []
    var activeRowIndex:NSIndexPath!
    var templateCell:ReminderItemTableViewCell!
    
    
    override func awakeFromNib() {
        self.cardFrame.layer.masksToBounds = true
        self.cardFrame.layer.shadowRadius = 10
        self.cardFrame.layer.cornerRadius = 10.0
        self.cardFrame.layer.borderWidth = 1.0
        self.cardFrame.layer.borderColor = UIColor.grayColor().CGColor
        self.cardActionButton.hidden = true
        tasksTableView.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2"))
        tasksTableView.contentInset = UIEdgeInsets(top: headerView.bounds.height, left: 0, bottom: 0, right: 0)
        let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)
        tasksTableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderItemCell")
        cardFrame.bringSubviewToFront(headerView)
        addHeaderBottomLineLayer()
        
        templateCell = reminderItemCellNib.instantiateWithOwner(nil, options: nil)[0] as ReminderItemTableViewCell
        templateCell.itemTextTopSpace.constant = 0
        
        contactImage.layer.cornerRadius = contactImage.frame.size.height/2
        contactImage.layer.masksToBounds = true
        contactImage.layer.borderWidth = 0
    }
    
    override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes!) {
        super.applyLayoutAttributes(layoutAttributes)
        self.layoutIfNeeded()
        templateCell.frame = CGRect(x: 0, y: 0, width: self.tasksTableView.frame.width, height: 44)
    }
    
    func addHeaderBottomLineLayer(){
        var line  = CAShapeLayer()
        var linePath = UIBezierPath()
        linePath.moveToPoint(CGPoint(x: 10, y: headerView.frame.height - 1))
        linePath.addLineToPoint(CGPoint(x: headerView.frame.width - 10, y: headerView.frame.height - 1))
        line.path = linePath.CGPath
        line.fillColor = nil
        line.opacity = 1.0
        line.strokeColor = UIColor.lightGrayColor().CGColor
        headerView.layer.addSublayer(line)
    }
    
    func initReminderCard(reminderCard:PFObject!,ownerContact:Contact) {
        self.ownerContact = ownerContact
        self.reminderCard = reminderCard
        self.cardName.text =  self.ownerContact.name
        if let image = ownerContact.image{
            self.contactImage.image = image
        }else {
            self.contactImage.image = UIImage(named: "default-avatar")
        }
        
        cardItems.removeAll(keepCapacity: false)
        for item in reminderCard[kReminderCardItems] as [NSDictionary]{
            cardItems.append(NSMutableDictionary(dictionary: item))
        }
        //last cell is for new entries
        cardItems.append(getNewItem())
        self.tasksTableView.reloadData()
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "tappedInsideTable:")
        tasksTableView.addGestureRecognizer(tapGestureRecognizer)
        refreshItemDescription()
        stackted()
    }
    
    func exposed(){
        self.invitationImage.hidden = false
        self.cardActionButton.setTitle("Edit", forState: UIControlState.Normal)
        self.cardActionButton.hidden = false
    }
    
    func stackted(){
         self.invitationImage.hidden = true
        self.cardActionButton.hidden = true
    }
    
    func actionSheet(actionSheet: UIActionSheet!, clickedButtonAtIndex buttonIndex: Int) {
        if actionSheet.cancelButtonIndex == buttonIndex{
            
        }else if actionSheet.destructiveButtonIndex == buttonIndex{
            self.reminderCollectionViewController.deleteReminderCard(self.reminderCard)
        }else {
            self.sendInvitation()
        }
    }
    
    func showActionSheetForInvitation(){
        var sheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: "Delete", otherButtonTitles: "Resend invitation" )
        sheet.showInView(self)
    }
    
    func getNewItem() -> NSMutableDictionary {
        var newItem = NSMutableDictionary()
        newItem[kReminderItemDescription] = ""
        newItem[kReminderItemStatus] = ReminderTaskStatus.New.toRaw()
        newItem[kReminderItemAlarmDate] = NSDate(timeIntervalSince1970: 0)
        return newItem
    }
    
    func appendNewItem() {
        cardItems.append(getNewItem())
        tasksTableView.insertRowsAtIndexPaths([NSIndexPath(forRow: cardItems.count - 1, inSection: 0)], withRowAnimation: UITableViewRowAnimation.None)
    }
    
    func refreshItemDescription() {
        self.cardDetails.text = "\(cardItems.count - 1) items"
    }
    
    func textView(textView: UITextView!, shouldChangeTextInRange range: NSRange, replacementText text: String!) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    func textViewDidBeginEditing(textView: UITextView!) {
        let point = textView.convertPoint(textView.frame.origin, fromView: self.tasksTableView)
        self.activeRowIndex = self.tasksTableView.indexPathForRowAtPoint(point)
        let activeRow = self.tasksTableView.cellForRowAtIndexPath(activeRowIndex)
        if !textView.text.isEmpty {
            activeRow.accessoryType = UITableViewCellAccessoryType.DetailButton
        }
        // expose this card if it is not exposed
        let indexPath = reminderCollectionViewController.collectionView.indexPathForCell(self)
        if indexPath != reminderCollectionViewController.exposedItemIndexPath {
            reminderCollectionViewController.exposedItemIndexPath = indexPath
        }
        tasksTableView.beginUpdates()
        tasksTableView.endUpdates()
        self.cardActionButton.setTitle("Done", forState: UIControlState.Normal)
    }
    
    func textViewDidEndEditing(textView: UITextView!) {
        var activeRow = tasksTableView.cellForRowAtIndexPath(activeRowIndex)
        activeRow.accessoryType = UITableViewCellAccessoryType.None
        saveActiveItem()
        tasksTableView.beginUpdates()
        tasksTableView.endUpdates()
        self.cardActionButton.setTitle("Edit", forState: UIControlState.Normal)
    }
    
    func textViewDidChange(textView: UITextView!) {
        var activeRow = tasksTableView.cellForRowAtIndexPath(activeRowIndex)
        var item = cardItems[activeRowIndex.row]
        item["description"] = textView.text
        if !textView.text.isEmpty {
            activeRow.accessoryType = UITableViewCellAccessoryType.DetailButton
        }else{
            activeRow.accessoryType = UITableViewCellAccessoryType.None
        }
        tasksTableView.beginUpdates()
        tasksTableView.endUpdates()
    }
    
    
    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if self.activeRowIndex != nil && self.activeRowIndex == indexPath{
            templateCell.accessoryType = UITableViewCellAccessoryType.DetailButton
        }else{
            templateCell.accessoryType = UITableViewCellAccessoryType.None
        }
        self.templateCell.layoutIfNeeded()
        let itemText = self.cardItems[indexPath.row]["description"] as String
        return max(templateCell.cellHeightThatFitsForItemText(itemText),44)
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return self.cardItems.count
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let itemCell:ReminderItemTableViewCell = self.tasksTableView.dequeueReusableCellWithIdentifier("ReminderItemCell") as ReminderItemTableViewCell
        itemCell.initForReminderCard(cardItems[indexPath.row])
        itemCell.selectionStyle = UITableViewCellSelectionStyle.None
        itemCell.itemTextView.delegate = self
        return itemCell
    }
    
    func tableView(tableView: UITableView!, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath!) {
        reminderCollectionViewController.performSegueWithIdentifier("ShowItemDetail", sender: indexPath)
    }
    
    @IBAction func tappedInsideTable(sender: UITapGestureRecognizer) {
        let touchPoint = sender.locationInView(sender.view)
        let itemIndexPath = tasksTableView.indexPathForRowAtPoint(touchPoint)
        let cellIndexPath = reminderCollectionViewController.collectionView.indexPathForCell(self)
        if reminderCollectionViewController.exposedItemIndexPath != cellIndexPath{
            reminderCollectionViewController.exposedItemIndexPath = cellIndexPath
        }
    }
    @IBAction func cardActionButtonPressed(sender: AnyObject) {
        if cardActionButton.titleLabel.text == "Done" {
            var activeRow = tasksTableView.cellForRowAtIndexPath(activeRowIndex) as ReminderItemTableViewCell
            activeRow.itemTextView.resignFirstResponder()
        }else{
            self.showActionSheetForInvitation()
        }
    }
    
    func tableView(tableView: UITableView!, canEditRowAtIndexPath indexPath: NSIndexPath!) -> Bool {
        if indexPath.row == cardItems.count - 1{
            return false
        }
        return true
    }
    
    func tableView(tableView: UITableView!, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath!) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            deleteItem(indexPath)
            tasksTableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        }
    }
    
    func deleteItem(indexPath:NSIndexPath){
        cardItems.removeAtIndex(indexPath.row)
        removeLastItemAndSave()
    }
    
    func saveActiveItem(){
        var activeRow = tasksTableView.cellForRowAtIndexPath(activeRowIndex) as ReminderItemTableViewCell
        if activeRowIndex.row == cardItems.count - 1{
            //new item
            if !activeRow.itemTextView.text.isEmpty{
                appendNewItem()
            }else{
                return
            }
        }
        removeLastItemAndSave()
    }
    
    func removeLastItemAndSave(){
        var saveItems = cardItems //clone the array
        saveItems.removeAtIndex(cardItems.count - 1)
        reminderCard["items"] = saveItems
        reminderCard.saveInBackground()
        refreshItemDescription()
    }
    
    func saveCardItemFrom(#taskEditViewController:TaskEditViewController){
        var editedItem = cardItems[activeRowIndex.row]
        editedItem["description"] = taskEditViewController.taskTextView.text
        if taskEditViewController.remindSwitch.on {
            editedItem["alarmDate"] = taskEditViewController.datePicker.date
        }else{
            editedItem["alarmDate"] = NSDate(timeIntervalSince1970: 0)
        }
        tasksTableView.reloadRowsAtIndexPaths([activeRowIndex], withRowAnimation: UITableViewRowAnimation.None)
        saveActiveItem()
    }
    
    func sendInvitation(){
        if MFMessageComposeViewController.canSendText() {
            let recipents = [reminderCard[kReminderCardOwner]]
            let messageController = MFMessageComposeViewController()
            messageController.messageComposeDelegate = self
            messageController.recipients = recipents
            messageController.body = "I sent you an reminder. \(appstoreUrl)"
            self.reminderCollectionViewController.presentViewController(messageController, animated: true, completion: nil)
        }
    }
    
    func invitationSent(userId:String){
        var invitation = PFObject(className: "Invitation")
        invitation["to"] = userId
        invitation["from"] = PFUser.currentUser().username
        invitation.saveInBackground()
    }
    
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        if result.value == MessageComposeResultFailed.value{
            UIAlertView(title: "Error", message: "Failed to send message", delegate: nil, cancelButtonTitle: "Continue").show()
        }else if result.value == MessageComposeResultSent.value {
            invitationSent(reminderCard[kReminderCardOwner] as String)
        }
        controller.dismissViewControllerAnimated(true, completion: nil)
    }

    
    /*
    func scrollViewDidScroll(scrollView: UIScrollView!) {
        for cell in self.tasksTableView.visibleCells() as [ReminderItemTableViewCell]{
            var maskOffset = scrollView.contentOffset.y + headerView.bounds.height - cell.frame.origin.y
            if maskOffset >= 0 {
                cell.maskOffset(maskOffset)
            }
        }
    }
    */
    
}
