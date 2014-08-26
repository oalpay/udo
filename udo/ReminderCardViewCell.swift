//
//  ReminderCardViewCell.swift
//  udo
//
//  Created by Osman Alpay on 02/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import UIKit
import QuartzCore

class ReminderCardViewCell : UICollectionViewCell,UITextViewDelegate,UITableViewDataSource,UITableViewDelegate{
    @IBOutlet weak var headerView: UIView!
    @IBOutlet var cardFrame : UIView!
    @IBOutlet var cardName : UILabel!
    @IBOutlet var cardDetails : UILabel!
    @IBOutlet var tasksTableView : UITableView!
    @IBOutlet var reminderCollectionViewController : RemindersCollectionViewController!
    @IBOutlet weak var cardActionButton: UIButton!
    
    
    var reminderCard:PFObject!
    var cardItems:[NSMutableDictionary] = []
    var activeRowIndex:NSIndexPath!
    
    
    override func awakeFromNib() {
        self.cardFrame.layer.masksToBounds = true
        self.cardFrame.layer.shadowRadius = 10
        self.cardFrame.layer.cornerRadius = 10.0
        self.cardFrame.layer.borderWidth = 1.0
        self.cardFrame.layer.borderColor = UIColor.grayColor().CGColor
        self.cardActionButton.hidden = true
        tasksTableView.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2"))
        tasksTableView.contentInset = UIEdgeInsets(top: headerView.bounds.height, left: 0, bottom: 0, right: 0)
        cardFrame.bringSubviewToFront(headerView)
        addHeaderBottomLineLayer()
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
    
    func initReminderCard(reminderCard:PFObject!) {
        self.reminderCard = reminderCard
        self.cardName.text = reminderCard["name"] as String
        cardItems.removeAll(keepCapacity: false)
        for item in reminderCard["items"] as [NSDictionary]{
            cardItems.append(NSMutableDictionary(dictionary: item))
        }
        //last cell is for new entries
        cardItems.append(getNewItem())
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "tappedInsideTable:")
        tasksTableView.addGestureRecognizer(tapGestureRecognizer)
        refreshItemDescription()
    }
    
    func getNewItem() -> NSMutableDictionary {
        var newItem = NSMutableDictionary()
        newItem["description"] = ""
        newItem["status"] = ReminderTaskStatus.New.toRaw()
        newItem["alarmDate"] = NSDate(timeIntervalSince1970: 0)
        return newItem
    }
    
    func appendNewItem() {
        cardItems.append(getNewItem())
        tasksTableView.insertRowsAtIndexPaths([NSIndexPath(forRow: cardItems.count - 1, inSection: 0)], withRowAnimation: UITableViewRowAnimation.None)
    }
    
    func refreshItemDescription() {
        self.cardDetails.text = "\(cardItems.count - 1) items"
    }
    
    
    
    func textViewDidBeginEditing(textView: UITextView!) {
        cardActionButton.hidden = false
        var activeRow = textView.superview?.superview as ReminderItemTableViewCell
        activeRowIndex = tasksTableView.indexPathForCell(activeRow)
        if !textView.text.isEmpty {
            activeRow.accessoryType = UITableViewCellAccessoryType.DetailButton
        }
        // expose this card if it is not exposed
        let indexPath = reminderCollectionViewController.collectionView.indexPathForCell(self)
        if indexPath != reminderCollectionViewController.exposedItemIndexPath {
            reminderCollectionViewController.exposedItemIndexPath = indexPath
        }
    }
    
    func textViewDidEndEditing(textView: UITextView!) {
        cardActionButton.hidden = true
        var activeRow = tasksTableView.cellForRowAtIndexPath(activeRowIndex)
        activeRow.accessoryType = UITableViewCellAccessoryType.None
        saveActiveItem()
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
        let text = self.cardItems[indexPath.row]["description"] as String
        let font = UIFont.systemFontOfSize(14)
        let attributes:Dictionary<String,AnyObject> = [NSFontAttributeName : font]
        let width = self.tasksTableView.frame.width - 44
        let rect = text.boundingRectWithSize(CGSizeMake(width,CGFloat.max) , options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: attributes, context: nil)
        return max(44,rect.height)
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return self.cardItems.count
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let itemCell:ReminderItemTableViewCell = self.tasksTableView.dequeueReusableCellWithIdentifier("ReminderTaskCell") as ReminderItemTableViewCell
        itemCell.initTaskCell(cardItems[indexPath.row],maskSize:CGSize(width: tableView.frame.width, height: headerView.frame.height))
        itemCell.selectionStyle = UITableViewCellSelectionStyle.None
        return itemCell
    }
    
    func tableView(tableView: UITableView!, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath!) {
        reminderCollectionViewController.performSegueWithIdentifier("TaskEdit", sender: indexPath)
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
        var activeRow = tasksTableView.cellForRowAtIndexPath(activeRowIndex) as ReminderItemTableViewCell
        activeRow.itemTextView.resignFirstResponder()
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

class ReminderItemTableViewCell: UITableViewCell {
    @IBOutlet weak var itemTextView : UITextView!
    @IBOutlet weak var checkButton: UIButton!
    @IBOutlet weak var alarmDateLabel: UILabel!
    
    let dateFormatter = NSDateFormatter()
    
    var maskLayer:CAShapeLayer!
    
    func initMaskLayer(size:CGSize){
        maskLayer = CAShapeLayer()
        let maskRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        maskLayer.path = CGPathCreateWithRect(maskRect, nil)
        self.layer.mask = maskLayer
    }
    
    func initTaskCell(reminderTask:NSDictionary!,maskSize:CGSize) {
        //initMaskLayer(maskSize)
        itemTextView.text = reminderTask["description"] as String
        let status = reminderTask["status"] as Int
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
    
}

