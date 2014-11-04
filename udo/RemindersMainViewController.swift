//
//  UDORemindersTableViewController.swift
//  udo
//
//  Created by Osman Alpay on 01/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import EventKit

var kReminderLastUpdate = "ReminderLastUpdate"

class RemindersMainViewController:UITableViewController,UISearchDisplayDelegate,UISearchBarDelegate{
    @IBOutlet weak var newReminderButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    var searchBar:UISearchBar!
    
    var contactsManager = ContactsManager.sharedInstance
    
    var reminderKeys = NSArray()
    
    var searchResults = NSArray()
    
    var reminderManager = ReminderManager.sharedInstance
    
    var notesManager = NotesManager.sharedInstance
    
    let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)
    
    var navSearchDisplayController:UISearchDisplayController!
    
    var oldTitleView:UIView!
    
    var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
    
    private var nc = NSNotificationCenter.defaultCenter()
    
    private var tableViewController:UITableViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.tableView.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2")!)
        self.tableView.backgroundColor = UIColor.whiteColor()
        self.tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderCell")
        self.tableView.setContentOffset(CGPoint(x: 0, y: 50), animated: false)
        
        self.settingsButton.target = self
        self.settingsButton.action = "settingsButtonPressed:"
        
        self.newReminderButton.target = self
        self.newReminderButton.action = "newReminderButtonPressed:"
        
        self.registerNotifications()
        
        UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName: AppTheme.logoColor, NSFontAttributeName: UIFont(name: "HelveticaNeue", size: 24)!]
        
        //self.navigationController?.navigationBar.titleTextAttributes =  [NSForegroundColorAttributeName: AppTheme.logoColor, NSFontAttributeName: UIFont(name: "HelveticaNeue", size: 24)!]
        
        if PFUser.currentUser() != nil {
            self.checkContactsAuthThenRefreshData()
        }
    }
    
    func unregisterFromNotifications(){
        self.nc.removeObserver(self)
    }
    
    func registerNotifications(){
        self.nc.addObserver(self, selector: "noteUpdatesAvailable:", name: kReminderNoteUpdatesAvailableNotification, object: nil)
        self.nc.addObserver(self, selector: "reminderShowNotification:", name: kReminderShowNotification, object: nil)
        self.nc.addObserver(self, selector: "remindersChangedNotification:", name: kRemindersChangedNotification, object: nil)
        self.nc.addObserver(self, selector: "reminderCreatedNotification:", name: kReminderCreatedNotification, object: nil)
        self.nc.addObserver(self, selector: "reminderLoadingNotification:", name: kReminderLoadingNotification, object: nil)
        self.nc.addObserver(self, selector: "reminderLoadingFinishedNotification:", name: kReminderLoadingFinishedNotification, object: nil)
        self.nc.addObserver(self, selector: "applicationWillEnterForegroundNotification:", name: UIApplicationWillEnterForegroundNotification, object: nil)
        self.nc.addObserver(self, selector: "userLoggedOut:", name: kUserLoggedOutNotification, object: nil)
        self.nc.addObserver(self, selector: "contactsChanged:", name: kContactsChangedNotification, object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        if let indexPath = self.tableView.indexPathForSelectedRow() {
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ReminderItemTableViewCell {
                self.markCell(cell)
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if PFUser.currentUser() == nil {
            self.performSegueWithIdentifier("Login", sender: self)
        }
    }
    
    func newReminderButtonPressed(sender:UIBarButtonItem){
        self.performSegueWithIdentifier("ShowReminder", sender: nil)
    }
    
    func settingsButtonPressed(sender:UIBarButtonItem) {
        self.performSegueWithIdentifier("ShowSettings", sender: nil)
    }
    
    func reminderShowNotification(notification:NSNotification){
        if let reminderId = notification.object as? String {
            self.showReminder(reminderId)
        }
    }
    
    func isReminderOpen(reminderId:String) -> Bool{
        for vc in self.navigationController!.viewControllers {
            if vc is ReminderViewController {
                var openReminderId = (vc as ReminderViewController).reminderKey
                if openReminderId == reminderId {
                    return true
                }
            }
        }
        return false
    }
    
    func noteUpdatesAvailable(notification:NSNotification){
        let reminderId = notification.object as String
        self.markReminder(reminderId)
    }
    
    func contactsChanged(notification:NSNotification) {
        self.updateVisibleCells()
    }
    
    func userLoggedOut(notification:NSNotification){
        self.reminderKeys = NSArray()
        self.tableView.reloadData()
    }
    func checkNotificationsEnabled(){
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate{
            if !appDelegate.isNotificationsEnabled() {
                self.performSegueWithIdentifier("NotificationsDisabled", sender: nil)
            }
        }
    }
    
    func checkContactsAuthThenRefreshData(){
        self.contactsManager.requestAccess { (success:Bool, error:NSError!) -> Void in
            if success {
                self.refreshContactsAndAppUsers()
            }else {
                self.performSegueWithIdentifier("ContactsAccessDenied", sender: nil)
            }
        }
    }
    
    func notifyUndoneOverdueReminders(inKeys:NSArray){
        for key in inKeys{
            let reminder = self.reminderManager.getReminder(key as String)
            if reminder.isOverDue(passIfDone: true){
                TSMessage.showNotificationWithTitle("You have reminders overdue", type: TSMessageNotificationType.Warning)
                return
            }
        }
    }
    
    
    func applicationWillEnterForegroundNotification( notification:NSNotification ){
        if PFUser.currentUser() != nil {
            self.reOrderTable()
            self.checkNotificationsEnabled()
            self.checkContactsAuthThenRefreshData()
            //self.notifyUndoneOverdueReminders(self.reminderKeys)
        }
    }
    
    func showReminder(key:String){
        if self.isReminderOpen(key){
            return
        }
        var index = self.nsReminderKeys().indexOfObject(key)
        if index != NSNotFound {
            self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
        }
        self.performSegueWithIdentifier("ShowReminder", sender: key)
    }
    
    func nsReminderKeys() -> NSArray {
        return self.reminderKeys as NSArray
    }
    
    // notifications
    func reminderCreatedNotification(notification:NSNotification){
        let keyInfo = notification.object as NSDictionary
        let oldKey = keyInfo["oldKey"] as String
        let index = self.nsReminderKeys().indexOfObject(oldKey)
        if index != NSNotFound {
            let newKey = keyInfo["newKey"] as String
            var keys = self.reminderKeys.mutableCopy() as NSMutableArray
            keys.replaceObjectAtIndex(index, withObject: newKey)
            self.reminderKeys = keys.copy() as NSArray
            if let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as? ReminderItemTableViewCell{
                cell.reminderKey = newKey
            }
        }
    }
    
    func reminderLoadingNotification(notification:NSNotification){
        var key = notification.object as String
        self.updateReminderCellActivity(key)
    }
    
    func reminderLoadingFinishedNotification(notification:NSNotification){
        var key = notification.object as String
        self.updateReminderCellActivity(key)
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
                reminderCell.updateAll()
            }
        }
    }
    
    func reOrderTable(){
        self.tableView.beginUpdates()
        let oldKeys = self.nsReminderKeys()
        var orderedKeys = oldKeys.mutableCopy() as NSMutableArray
        orderedKeys.sortUsingComparator(self.reminderManager.reminderComparator)
        for var newIndex = 0; newIndex < orderedKeys.count; newIndex++ {
            let key = orderedKeys.objectAtIndex(newIndex) as String
            let oldIndex = oldKeys.indexOfObject(key)
            if oldIndex != NSNotFound && oldIndex != newIndex {
                self.tableView.moveRowAtIndexPath(NSIndexPath(forRow: oldIndex, inSection: 0), toIndexPath: NSIndexPath(forRow: newIndex, inSection: 0))
            }
        }
        self.reminderKeys = NSArray(array: orderedKeys)
        self.tableView.endUpdates()
    }
    
    func mergeReminders(change:RemindersChanged){
        let currentKeys = self.nsReminderKeys()
        self.tableView.beginUpdates()
        var mergedKeys = self.reminderKeys.mutableCopy() as NSMutableArray
        for key in change.deletes {
            var deleteIndex = currentKeys.indexOfObject(key)
            if deleteIndex != NSNotFound {
                mergedKeys.removeObjectAtIndex(deleteIndex)
                self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: deleteIndex, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Left)
            }
        }
        if change.inserts.count > 0 {
            var sortedInserts = NSMutableArray(array: change.inserts)
            sortedInserts.sortUsingComparator(self.reminderManager.reminderComparator)
            for (var index = 0; index < sortedInserts.count; index++){
                let key = sortedInserts[index] as String
                mergedKeys.insertObject(key, atIndex: index)
                self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Automatic)
            }
        }
        // move all updated reminders below newly added ones
        if change.updates.count > 0 {
            if !change.isLocalChange {
                var keysBeforeMove = mergedKeys.copy() as NSArray
                // remove from old positions
                for key in change.updates {
                    let index = mergedKeys.indexOfObject(key)
                    mergedKeys.removeObjectAtIndex(index)
                }
                // insert into new positions
                for (var index = 0; index < change.updates.count; index++){
                    let moveToIndex = change.inserts.count + index
                    mergedKeys.insertObject(change.updates[index], atIndex: moveToIndex)
                }
                for (var index = change.inserts.count; index < mergedKeys.count; index++){
                    let key = mergedKeys.objectAtIndex(index) as String
                    let oldIndex = keysBeforeMove.indexOfObject(key)
                    if oldIndex != index{
                        self.tableView.moveRowAtIndexPath(NSIndexPath(forRow: oldIndex, inSection: 0), toIndexPath: NSIndexPath(forRow: index, inSection: 0))
                    }
                }
            }
        }
        self.reminderKeys = mergedKeys.copy() as NSArray
        self.tableView.endUpdates()
        
        // update visible cells
        for key in change.updates {
            let index = mergedKeys.indexOfObject(key)
            if let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as? ReminderItemTableViewCell {
                cell.reminderKey = key
                cell.updateAll()
                self.markCell(cell)
            }
        }
        //self.notifyUndoneOverdueReminders((change.inserts as NSArray).arrayByAddingObjectsFromArray(change.updates))
    }
    
    
    func updateVisibleCells(){
        var cells = self.tableView.visibleCells() as [ReminderItemTableViewCell]
        for cell in cells {
            cell.updateTitle()
            cell.updateAlaramLabels()
            self.markCell(cell)
        }
    }
    
    
    func refreshContactsAndAppUsers() {
        self.showActivity()
        self.contactsManager.loadContacts { () -> Void in
            self.contactsManager.refreshAppUsers({ () -> Void in
                self.updateVisibleCells()
                self.hideActivity()
            })
        }
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
            if let reminderKey = sender as? String{
                reminderVC.reminderKey = reminderKey
            }
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
    
    
    /*
    * mark cell if not seen
    * mark cell if due date is passes and its undone
    */
    func markCell(cell:ReminderItemTableViewCell){
        let reminderKey = cell.reminderKey
        let reminderState = self.reminderManager.getReminderState(reminderKey)
        cell.setAccessoryColorForState(reminderState)
    }
    
    func markReminder(reminderId:String){
        var index = self.nsReminderKeys().indexOfObject(reminderId)
        if index != NSNotFound {
            if let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as? ReminderItemTableViewCell{
                self.markCell(cell)
            }
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var reminderCell = tableView.dequeueReusableCellWithIdentifier("ReminderCell", forIndexPath: indexPath) as ReminderItemTableViewCell
        var key:String!
        if self.tableView == tableView {
            key = self.reminderKeys.objectAtIndex(indexPath.row) as String
        }else{
            key = self.searchResults.objectAtIndex(indexPath.row) as String
        }
        reminderCell.reminderKey = key
        reminderCell.updateAll()
        self.markCell(reminderCell)
        return reminderCell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var key:String!
        if tableView == self.tableView {
            key = self.reminderKeys.objectAtIndex(indexPath.row) as String
        }else{
            key = self.searchResults.objectAtIndex(indexPath.row) as String
        }
        self.performSegueWithIdentifier("ShowReminder", sender: key)
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        var key = self.reminderKeys.objectAtIndex(indexPath.row) as String
        if self.reminderManager.isReminderLoadingWithKey(key) {
            return false
        }
        return true
    }
    
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        var key = self.reminderKeys.objectAtIndex(indexPath.row) as String
        if self.reminderManager.isReminderLoadingWithKey(key) {
            return UITableViewCellEditingStyle.None
        }
        return UITableViewCellEditingStyle.Delete
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        var key = self.reminderKeys.objectAtIndex(indexPath.row) as String
        self.reminderManager.deleteReminder(key)
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, didLoadSearchResultsTableView tableView: UITableView!) {
        tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderCell")
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, shouldReloadTableForSearchString searchString: String!) -> Bool {
        var newSearchResults = NSMutableArray()
        for key in self.reminderKeys {
            var reminder = self.reminderManager.getReminder(key as String)
            for token in reminder.title.componentsSeparatedByString(" ") as [String]{
                if token.lowercaseString.hasPrefix(searchString.lowercaseString){
                    newSearchResults.addObject(reminder.key())
                    break
                }
            }
        }
        let oldResultSet:NSSet = NSSet(array: self.searchResults)
        let newResultSet:NSSet = NSSet(array: newSearchResults)
        if !oldResultSet.isEqualToSet(newResultSet){
            self.searchResults = newSearchResults.copy() as NSArray
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

class NotificationsDisabledWarningViewController:UIViewController{
    @IBOutlet weak var dismissButton: UIButton!
    override func viewDidLoad() {
        let dismissImage = UIImage(named: "croos")?.imageTintedWithColor(AppTheme.tintColor)
        self.dismissButton.setImage(dismissImage, forState: UIControlState.Normal)
        self.dismissButton.setImage(dismissImage, forState: UIControlState.Highlighted)
    }
    override func viewWillAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBeconeActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    func applicationDidBeconeActive( notification:NSNotification ){
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate{
            if appDelegate.isNotificationsEnabled() {
                self.performSegueWithIdentifier("NotificationsEnabled", sender: nil)
            }
        }
    }
}