//
//  UDORemindersTableViewController.swift
//  udo
//
//  Created by Osman Alpay on 01/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import EventKit


class RemindersMainViewController:UIViewController,UISearchDisplayDelegate,UITableViewDataSource,UITableViewDelegate{
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    var contactsHelper = ContactsHelper.sharedInstance
    var reminders:[Reminder] = []
    var searchResults:[Reminder] = []
    
    var reminderManager = UDOReminderManager.sharedInstance
    
    let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2"))
        self.tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderCell")
        
        var refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
        
        if (PFUser.currentUser() != nil ) {
            self.userLoggedIn()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func reminderChangedNotificationReceived( notification:NSNotification ){
        self.refresh(nil)
    }
    
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
        if unwindSegue.identifier == "Loggedin"{
            self.userLoggedIn()
        }else if unwindSegue.identifier == "SaveItemEdit" {
            //save item
            let reminderVC = unwindSegue.sourceViewController as ReminderViewController
            self.saveItemFromReminderVC(reminderVC)
        }
    }
    
    func saveItemFromReminderVC(reminderVC:ReminderViewController){
        let reminder = reminderVC.reminder
        if reminder.title != reminderVC.taskTextView.text{
            reminder.title = reminderVC.taskTextView.text
        }
        if reminderVC.dueDateSwitchAdmin.on {
            if (reminder.dueDate == nil || ( reminder.dueDate != nil && !reminder.dueDate.isEqualToDate(reminderVC.dueDatePickerAdmin.date))) {
                reminder.dueDate = reminderVC.dueDatePickerAdmin.date
            }
        }else if reminder.dueDate != nil {
            reminder.dueDate = nil
        }
        //only admin can change collaborator
        var addedItemsAfterSave:NSArray!
        if reminder.collaborators.first? == PFUser.currentUser().username {
            // parse cannot hande addAtomic and removeAtomic at the same time
            // do addAtomic after save
            var removedItems = NSMutableArray(array: reminder.collaborators)
            removedItems.removeObjectsInArray(reminderVC.collaborators)
            if removedItems.count > 0 {
                reminder.removeObjectsInArray(removedItems, forKey: kReminderCollaborators)
            }
            var addedItems = NSMutableArray(array: reminderVC.collaborators)
            addedItems.removeObjectsInArray(reminder.collaborators)
            if removedItems.count == 0 && addedItems.count > 0 {
                reminder.addUniqueObjectsFromArray(addedItems, forKey: kReminderCollaborators)
            } else if removedItems.count > 0 && addedItems.count > 0 {
                addedItemsAfterSave = addedItems
            }
        }
        
        var reminderManager = UDOReminderManager.sharedInstance
        var isOnMyReminders = false
        if reminder.objectId != nil {
            isOnMyReminders = reminderManager.isReminderOnCalendar(reminder)
        }
        var isAddToMyCalendarOn = reminderVC.addToMyRemindersSwitch.on
        
        var alarmDate:NSDate!
        if reminderVC.remindMeOnADaySwitch.on {
            alarmDate = reminderVC.remindMeDatePicker.date
        }
        
        self.saveReminder(reminder, onSuccess: { () -> Void in
            if isAddToMyCalendarOn {
                UDOReminderManager.sharedInstance.mergeReminderToEventStore(reminder, alarmDate: alarmDate)
            }else if isOnMyReminders {
                UDOReminderManager.sharedInstance.removeReminderFromEventStore(reminder)
            }
            if addedItemsAfterSave != nil {
                reminder.addUniqueObjectsFromArray(addedItemsAfterSave, forKey: kReminderCollaborators)
                reminder.saveEventually()
            }
        })
    }
    
    func findReminderIndexPath(objectId:String) -> NSIndexPath? {
        for (var index = 0; index < self.reminders.count; index++){
            var reminder = self.reminders[index]
            if (reminder.objectId != nil && reminder.objectId == objectId) {
                return NSIndexPath(forRow: index, inSection: 0)
            }
        }
        return nil
    }
    
    
    func saveReminder(reminder:Reminder, onSuccess:() -> Void){
        reminder.saveInBackgroundWithBlock { (success:Bool, _ ) -> Void in
            if success {
                onSuccess()
            }
        }
        if reminder.objectId == nil {
            //new item
            self.reminders.insert(reminder, atIndex: 0)
            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Automatic)
        }else{
            var selectedIndexPathOption = self.findReminderIndexPath(reminder.objectId)
            if let selectedIndexPath = selectedIndexPathOption {
                if selectedIndexPath.row == 0 {
                    self.tableView.reloadRowsAtIndexPaths([selectedIndexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                }else{
                    self.tableView.beginUpdates()
                    self.reminders.removeAtIndex(selectedIndexPath.row)
                    self.tableView.deleteRowsAtIndexPaths([selectedIndexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                    self.reminders.insert(reminder, atIndex: 0)
                    self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection:0)], withRowAnimation: UITableViewRowAnimation.Automatic)
                    self.tableView.endUpdates()
                }
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowReminder"{
            let reminderVC = segue.destinationViewController as ReminderViewController
            reminderVC.reminder = sender as Reminder
        }else if segue.identifier == "ShowContacts"{
            let navC = segue.destinationViewController as UINavigationController
            let contactsVC = navC.topViewController as  ContactsViewController
            contactsVC.contactsHelper = self.contactsHelper
        }
    }
    
    
    override func viewDidAppear(animated: Bool) {
        if PFUser.currentUser() == nil{
            self.performSegueWithIdentifier("Login", sender: self)
        }
    }
    
    @IBAction func newReminderCardButtonPressed(sender: AnyObject) {
        var reminder = Reminder()
        reminder.title = ""
        reminder.collaborators = [PFUser.currentUser().username]
        self.performSegueWithIdentifier("ShowReminder", sender: reminder)
    }
    
    func refresh(refreshControl:UIRefreshControl) {
        self.refresh { () -> Void in
            refreshControl.endRefreshing()
        }
    }
    
    func mergeReminders(newReminders:[Reminder]){
        var index = 0
        var insertIndexes = [NSIndexPath]()
        self.tableView.beginUpdates()
        for newReminder in newReminders {
            insertIndexes.append(NSIndexPath(forRow: index++, inSection: 0))
            var existingIndexPathOption = self.findReminderIndexPath(newReminder.objectId)
            if let existingIndexPath = existingIndexPathOption{
                self.reminders.removeAtIndex(existingIndexPath.row)
                self.tableView.deleteRowsAtIndexPaths([existingIndexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            }
        }
        for newReminders in newReminders {
            self.reminders.insert(newReminders, atIndex: 0)
        }
        self.tableView.insertRowsAtIndexPaths(insertIndexes, withRowAnimation: UITableViewRowAnimation.Automatic)
        self.tableView.endUpdates()
    }
    
    func refresh( done: (() -> Void)? ){
        var lastUpdated = NSDate(timeIntervalSince1970: 0)
        for reminder in self.reminders {
            if reminder.updatedAt != nil {
                if lastUpdated.compare(reminder.updatedAt) == NSComparisonResult.OrderedAscending {
                    lastUpdated = reminder.updatedAt
                }
            }
        }
        let remindersQuery = Reminder.query()
        remindersQuery.whereKey(kReminderCollaborators,equalTo:PFUser.currentUser().username)
        remindersQuery.whereKey("updatedAt", greaterThan: lastUpdated)
        remindersQuery.orderByAscending("updatedAt")
        remindersQuery.findObjectsInBackgroundWithBlock({
            (reminders:[AnyObject]!, error: NSError!) -> Void in
            done?()
            if error == nil{
                self.mergeReminders(reminders as [Reminder])
                NSNotificationCenter.defaultCenter().postNotificationName(KRemindersChangedNotification, object: self.reminders)
            }else{
                //handle error
                println("getReminders: \(error)")
            }
            
        })
    }
    
    func userLoggedIn(){
        self.checkPushNotifications()
        self.contactsHelper.authorize({ () -> Void in
            self.refresh({ () -> Void in
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "reminderChangedNotificationReceived:", name: KReminderPushReceivedNotification, object: nil)
            })
            }, fail: { () -> Void in
                UIAlertView(title: "Error", message: "Contacts access failed!", delegate: nil, cancelButtonTitle: nil).show()
                return
        })
    }
    
    func checkPushNotifications(){
        var application = UIApplication.sharedApplication()
        if application.isRegisteredForRemoteNotifications() {
            //           return
        }
        // Register for Push Notitications, if running iOS 8
        if (application.respondsToSelector("registerUserNotificationSettings:")) {
            var userNotificationTypes = UIUserNotificationType.Alert | UIUserNotificationType.Badge | UIUserNotificationType.Sound
            var settings =  UIUserNotificationSettings(forTypes: userNotificationTypes, categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        } else {
            // Register for Push Notifications before iOS 8
            application.registerForRemoteNotificationTypes(UIRemoteNotificationType.Alert | UIRemoteNotificationType.Badge | UIRemoteNotificationType.Sound)
        }
        
        
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 70.0
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.tableView == tableView {
            return reminders.count
        }else{
            //search
            return searchResults.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var reminderCell = tableView.dequeueReusableCellWithIdentifier("ReminderCell", forIndexPath: indexPath) as ReminderItemTableViewCell
        var reminder:Reminder!
        if self.tableView == tableView {
            reminder = self.reminders[indexPath.row]
        }else{
            reminder = self.searchResults[indexPath.row]
        }
        reminderCell.setReminder(reminder)
        return reminderCell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if self.tableView == tableView{
            self.performSegueWithIdentifier("ShowReminder", sender: self.reminders[indexPath.row])
        }else{
            self.performSegueWithIdentifier("ShowReminder", sender: self.searchResults[indexPath.row])
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        var reminder = self.reminders[indexPath.row]
        reminder.removeObject(PFUser.currentUser().username, forKey: kReminderCollaborators)
        reminder.removeObject(PFUser.currentUser().username, forKey: kReminderDones)
        reminder.saveEventually()
        self.reminders.removeAtIndex(indexPath.row)
        self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, didLoadSearchResultsTableView tableView: UITableView!) {
        tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderCell")
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, shouldReloadTableForSearchString searchString: String!) -> Bool {
        var newSearchResults:[Reminder] = []
        for reminder in self.reminders {
            for token in reminder.title.componentsSeparatedByString(" ") as [String]{
                if token.lowercaseString.hasPrefix(searchString.lowercaseString){
                    newSearchResults.append(reminder)
                    break
                }
            }
        }
        let oldResultSet:NSSet = NSSet(array: self.searchResults)
        let newResultSet:NSSet = NSSet(array: newSearchResults)
        if !oldResultSet.isEqualToSet(newResultSet){
            self.searchResults = newSearchResults
            return true
        }
        return false
    }
    
}