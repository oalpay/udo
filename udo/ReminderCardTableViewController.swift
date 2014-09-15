//
//  ReminderCardTableViewController.swift
//  udo
//
//  Created by Osman Alpay on 01/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class ReminderCardTableViewController: UITableViewController,UITextViewDelegate{
    var contactImgButton:UIButton!
    var contactHelper:ContactsHelper!
    var contact:Contact!
    var reminderCard:PFObject!{
        didSet{
            for item in self.reminderCard[kReminderCardItems] as [NSDictionary]{
                cardItems.append(NSMutableDictionary(dictionary: item))
            }
            //last cell is for new entries
            cardItems.append(getNewItem())
            self.contact = contactHelper.getContactForUserId(reminderCard[kReminderCardOwner] as String)
            self.title = contact.name
            if let img = self.contact.image{
                 contactImgButton.setBackgroundImage(img, forState: UIControlState.Normal)
            }
        }
    }
    var cardItems:[NSMutableDictionary] = []
    var templateCell:ReminderItemTableViewCell!
    
    override func awakeFromNib() {
        self.tableView.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2"))
        let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)
        self.tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderItemCell")
        
        templateCell = reminderItemCellNib.instantiateWithOwner(nil, options: nil)[0] as ReminderItemTableViewCell
        templateCell.frame = CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: 44)
        templateCell.itemTextTopSpace.constant = 0
        
        self.contactImgButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        contactImgButton.layer.cornerRadius = contactImgButton.frame.size.height/2
        contactImgButton.layer.masksToBounds = true
        contactImgButton.layer.borderWidth = 0
        self.contactImgButton.setBackgroundImage(defaultContactImage, forState: UIControlState.Normal)
        let contactImgBarButton = UIBarButtonItem(customView: contactImgButton)
        self.navigationItem.rightBarButtonItem = contactImgBarButton
        
    }
    
    override func viewDidLoad() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "tappedInsideTable:")
        tableView.addGestureRecognizer(tapGestureRecognizer)
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
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: cardItems.count - 1, inSection: 0)], withRowAnimation: UITableViewRowAnimation.None)
    }
    
    
    func textView(textView: UITextView!, shouldChangeTextInRange range: NSRange, replacementText text: String!) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    func indexPathOfCellSubview(view:UIView) -> NSIndexPath? {
        let point = self.tableView.convertPoint(view.frame.origin, fromView: view)
        return self.tableView.indexPathForRowAtPoint(point)
    }
    
    func textViewDidBeginEditing(textView: UITextView!) {
        let itemIndexPath = indexPathOfCellSubview(textView)!
        self.tableView.selectRowAtIndexPath(itemIndexPath, animated: true, scrollPosition: UITableViewScrollPosition.None)
        let activeRow = self.tableView.cellForRowAtIndexPath(itemIndexPath)!
        if !textView.text.isEmpty {
            activeRow.accessoryType = UITableViewCellAccessoryType.DetailButton
        }
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func textViewDidEndEditing(textView: UITextView!) {
        let itemIndexPath = indexPathOfCellSubview(textView)!
        let activeRow = self.tableView.cellForRowAtIndexPath(itemIndexPath)!
        activeRow.accessoryType = UITableViewCellAccessoryType.None
        saveCard()
        self.tableView.reloadRowsAtIndexPaths([itemIndexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func textViewDidChange(textView: UITextView!) {
        let itemIndexPath = indexPathOfCellSubview(textView)!
        var activeRow = tableView.cellForRowAtIndexPath(itemIndexPath) as ReminderItemTableViewCell
        var item = cardItems[itemIndexPath.row]
        item[kReminderItemDescription] = textView.text
        if !textView.text.isEmpty {
            activeRow.accessoryType = UITableViewCellAccessoryType.DetailButton
        }else{
            activeRow.accessoryType = UITableViewCellAccessoryType.None
        }
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if self.tableView.indexPathForSelectedRow() != nil && self.tableView.indexPathForSelectedRow() == indexPath{
            templateCell.accessoryType = UITableViewCellAccessoryType.DetailButton
        }else{
            templateCell.accessoryType = UITableViewCellAccessoryType.None
        }
        self.templateCell.layoutIfNeeded()
        let itemText = self.cardItems[indexPath.row][kReminderItemDescription] as String
        return max(templateCell.cellHeightThatFitsForItemText(itemText),44.0)
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.cardItems.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let itemCell:ReminderItemTableViewCell = self.tableView.dequeueReusableCellWithIdentifier("ReminderItemCell") as ReminderItemTableViewCell
        itemCell.initForReminderCard(cardItems[indexPath.row])
        itemCell.selectionStyle = UITableViewCellSelectionStyle.None
        itemCell.itemTextView.delegate = self
        if indexPath.row == cardItems.count - 1 {
            //last item
            itemCell.checkButton.hidden = true
        }
        return itemCell
    }
    
    override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("ShowItemDetail", sender: indexPath)
    }
    
    @IBAction func tappedInsideTable(sender: UITapGestureRecognizer) {
        
    }
    
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if indexPath.row == cardItems.count - 1{
            return false
        }
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            deleteItem(indexPath)
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        }
    }
    
    func deleteItem(indexPath:NSIndexPath){
        cardItems.removeAtIndex(indexPath.row)
        removeLastItemAndSave()
    }
    
    func saveCard(){
        let lastItem = cardItems.last
        let description = lastItem?[kReminderItemDescription] as NSString?
        if description? != ""{
            appendNewItem()
        }
        removeLastItemAndSave()
    }
    
    func removeLastItemAndSave(){
        var saveItems = cardItems //clone the array
        saveItems.removeAtIndex(cardItems.count - 1)
        reminderCard[kReminderCardItems] = saveItems
        reminderCard.saveInBackground()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowItemDetail"{
            var itemEditVC = segue.destinationViewController as TaskEditViewController
            itemEditVC.editItem(self.reminderCard, itemIndex: self.tableView.indexPathForSelectedRow()!.row)
        }
    }
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
        if unwindSegue.identifier == "SaveItemEdit" {
            var itemEditVC = unwindSegue.sourceViewController as TaskEditViewController
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: itemEditVC.itemIndex, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Automatic)
            saveCard()
        }
    }
    
    
    /*
    func saveCardItemFrom(#taskEditViewController:TaskEditViewController){
    let itemIndexPath = self.tableView.indexPathForSelectedRow()
    var editedItem = cardItems[itemIndexPath]
    editedItem["description"] = taskEditViewController.taskTextView.text
    if taskEditViewController.remindSwitch.on {
    editedItem["alarmDate"] = taskEditViewController.datePicker.date
    }else{
    editedItem["alarmDate"] = NSDate(timeIntervalSince1970: 0)
    }
    tableView.reloadRowsAtIndexPaths([activeRowIndex], withRowAnimation: UITableViewRowAnimation.None)
    saveActiveItem()
    }
    */
    
}
