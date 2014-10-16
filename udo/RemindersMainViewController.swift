//
//  UDORemindersTableViewController.swift
//  udo
//
//  Created by Osman Alpay on 01/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import EventKit


class RemindersMainViewController:UITableViewController,UISearchDisplayDelegate,EventStoreManagerDelegate{
    var contactsManager = ContactsManager.sharedInstance
    
    var reminderKeys:[String] = []
    
    var searchResults:[String] = []
    
    var eventStoreManager = EventStoreManager.sharedInstance
    
    var reminderManager = ReminderManager.sharedInstance
    
    let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)
    
    var navSearchDisplayController:UISearchDisplayController!
    
    var oldTitleView:UIView!
    
    var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2"))
        self.tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderCell")
        self.tableView.setContentOffset(CGPoint(x: 0, y: 44), animated: true)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "remindersChangedNotification:", name: kRemindersChangedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reminderLoadingNotification:", name: kReminderLoadingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reminderLoadingFinishedNotification:", name: kReminderLoadingFinishedNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationWillEnterForegroundNotification:", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "userLoggedOut:", name: kUserLoggedOutNotification, object: nil)
        
        self.eventStoreManager.delegate = self
        
        self.navigationController?.navigationBar.titleTextAttributes =  [NSForegroundColorAttributeName: AppTheme.logoColor, NSFontAttributeName: UIFont(name: "HelveticaNeue", size: 22)]
        
        if PFUser.currentUser() != nil {
            self.checkContactsAuthThenRefreshData()
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if PFUser.currentUser() == nil {
            self.performSegueWithIdentifier("Login", sender: self)
        }
    }
    
    func userLoggedOut(notification:NSNotification){
        self.reminderKeys.removeAll(keepCapacity: true)
        self.tableView.reloadData()
    }
    
    func showReminder(key:String){
        var index = self.nsReminderKeys().indexOfObject(key)
        if index != NSNotFound {
            self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
        }
        self.performSegueWithIdentifier("ShowReminder", sender: key)
    }
    
    func nsReminderKeys() -> NSArray {
        return self.reminderKeys as NSArray
    }
    
    func itemChangedInStore(key:String!){
        var index = self.nsReminderKeys().indexOfObject(key)
        if index != NSNotFound {
            if let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) {
                var reminderCell = cell as ReminderItemTableViewCell
                reminderCell.updateAlaramLabels()
            }
        }
    }
    
    // notifications
    func reminderLoadingNotification(notification:NSNotification){
        var key = notification.object as String
        self.updateReminderCellActivity(key)
    }
    
    func reminderLoadingFinishedNotification(notification:NSNotification){
         var key = notification.object as String
        self.updateReminderCellActivity(key)
        //if reminder was new key is changed to objectId
        var reminder = self.reminderManager.getReminder(key)
        if reminder.objectId != key {
            var index = self.nsReminderKeys().indexOfObject(key)
            if  index != NSNotFound {
                self.reminderKeys.removeAtIndex(index)
                self.reminderKeys.insert(reminder.key(), atIndex: index)
                var cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as ReminderItemTableViewCell?
                cell?.reminderKey = reminder.key()
            }
        }
    }
    
    func remindersChangedNotification(notification:NSNotification){
        var change = notification.object as RemindersChanged!
        self.mergeReminders(change)
    }
    // notifications end
    
    func updateReminderCellActivity(key:String){
        var index = self.nsReminderKeys().indexOfObject(key)
        if index != NSNotFound {
            if let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) {
                var reminderCell = cell as ReminderItemTableViewCell
                reminderCell.updateActivity()
                reminderCell.updateErrorMsg()
                reminderCell.updateAlaramLabels()
                reminderCell.updateCalendarLabels()
            }
        }
    }

    
    func mergeReminders(change:RemindersChanged){
        var insertKeys = NSMutableArray(array: change.inserts)
        insertKeys.sortUsingComparator { (key1:AnyObject!, key2:AnyObject!) -> NSComparisonResult in
            var r1 = self.reminderManager.getReminder(key1 as String)
            var r2 = self.reminderManager.getReminder(key2 as String)
            if let r1Date = r1.updatedAt {
                if let r2Date = r2.updatedAt {
                    return r1Date.compare(r2Date)
                }else{
                    return NSComparisonResult.OrderedAscending
                }
            }else{
                return NSComparisonResult.OrderedDescending
            }
        }
        var mergedKeys = NSMutableArray(array: self.reminderKeys)
        for newKey in insertKeys {
            if mergedKeys.indexOfObject(newKey) == NSNotFound {
                mergedKeys.insertObject(newKey, atIndex: 0)
            }
        }
        // save old keys
        var oldKeys = self.nsReminderKeys()
        self.tableView.beginUpdates()
        self.reminderKeys = NSArray(array: mergedKeys) as [String]
        for ( var index = 0; index < mergedKeys.count; index++ ) {
            var key = mergedKeys.objectAtIndex(index) as String
            var indexPath = NSIndexPath(forRow: index, inSection: 0)
            var oldIndex = oldKeys.indexOfObject(key)
            if oldIndex != NSNotFound {
                if index != oldIndex {
                    //moved
                    self.tableView.moveRowAtIndexPath(NSIndexPath(forRow: oldIndex, inSection: 0), toIndexPath: indexPath)
                }
            }else {
                // new
                self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            }
        }
        self.tableView.endUpdates()
        for key in change.updates {
            var index = self.nsReminderKeys().indexOfObject(key)
            if index != NSNotFound {
                var cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as ReminderItemTableViewCell?
                cell?.updateAll()
            }
        }
    }
    
    
    
    func checkContactsAuthThenRefreshData(){
        self.contactsManager.authorize({ () -> Void in
            self.refreshContactsAndAppUsers()
            }, error: { () -> Void in
                self.performSegueWithIdentifier("ContactsAccessDenied", sender: nil)
        })
    }
    
    
    func applicationWillEnterForegroundNotification( notification:NSNotification ){
        if PFUser.currentUser() != nil {
            self.checkContactsAuthThenRefreshData()
        }
    }
    
    
    
    func refreshContactsAndAppUsers() {
        self.showActivity()
        self.contactsManager.refreshContactsAndAppUsers({ () -> Void in
            var cells = self.tableView.visibleCells() as [ReminderItemTableViewCell]
            for cell in cells {
                cell.updateTitle()
                cell.updateAlaramLabels()
            }
            }, appUsersLoaded: { () -> Void in
                self.hideActivity()
        })
    }
    
    @IBAction func refreshActivated(refreshControl: UIRefreshControl) {
        refreshControl.beginRefreshing()
        self.reminderManager.refresh { (_, _) -> Void in
            refreshControl.endRefreshing()
        }
    }
    
    
    
    @IBAction func newReminderCardButtonPressed(sender: AnyObject) {
        self.performSegueWithIdentifier("ShowReminder", sender: nil)
    }
    
    
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
        if unwindSegue.identifier == "ContactsAccessGranted"{
            self.refreshContactsAndAppUsers()
        }else if unwindSegue.identifier == "Loggedin"{
            self.checkContactsAuthThenRefreshData()
        }else if unwindSegue.identifier == "SaveItemEdit" {
            
        }
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowReminder"{
            let reminderVC = segue.destinationViewController as ReminderViewController
            reminderVC.reminderKey = sender as String!
        }else if segue.identifier == "ShowContacts"{
            let navC = segue.destinationViewController as UINavigationController
            let contactsVC = navC.topViewController as  ContactsViewController
        }
    }
    
    func showActivity(){
        self.activityIndicator.startAnimating()
        self.navigationItem.titleView = activityIndicator
    }
    
    func hideActivity(){
        self.activityIndicator.stopAnimating()
        self.navigationItem.titleView = nil
    }
    
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 70.0
    }
    
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.tableView == tableView {
            return self.reminderKeys.count
        }else{
            //search
            return searchResults.count
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var reminderCell = tableView.dequeueReusableCellWithIdentifier("ReminderCell", forIndexPath: indexPath) as ReminderItemTableViewCell
        var key:String!
        if self.tableView == tableView {
            key = self.reminderKeys[indexPath.row]
        }else{
            key = self.searchResults[indexPath.row]
        }
        reminderCell.reminderKey = key
        reminderCell.updateAll()
        return reminderCell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var key:String!
        if tableView == self.tableView {
            key = self.reminderKeys[indexPath.row]
        }else{
            key = self.searchResults[indexPath.row]
        }
        self.performSegueWithIdentifier("ShowReminder", sender: key)
    }
    
    override  func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        var key = self.reminderKeys[indexPath.row]
        self.reminderManager.deleteReminder(key)
        self.reminderKeys.removeAtIndex(indexPath.row)
        self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, didLoadSearchResultsTableView tableView: UITableView!) {
        tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderCell")
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, shouldReloadTableForSearchString searchString: String!) -> Bool {
        var newSearchResults:[String] = []
        for key in self.reminderKeys {
            var reminder = self.reminderManager.getReminder(key)
            for token in reminder.title.componentsSeparatedByString(" ") as [String]{
                if token.lowercaseString.hasPrefix(searchString.lowercaseString){
                    newSearchResults.append(reminder.key())
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

class ContactsAccessWarningViewController:UIViewController{
    override func viewWillAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBeconeActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    func applicationDidBeconeActive( notification:NSNotification ){
        if ContactsManager.sharedInstance.isAuthorized() {
            self.performSegueWithIdentifier("ContactsAccessGranted", sender: nil)
        }
    }
}