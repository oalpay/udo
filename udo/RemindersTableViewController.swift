//
//  UDORemindersTableViewController.swift
//  udo
//
//  Created by Osman Alpay on 01/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import EventKit

let defaultContactImage = UIImage(named: "default-avatar")

class ReminderTableViewCell:UITableViewCell{
    @IBOutlet weak var contactImage: UIImageView!
    @IBOutlet weak var contactName: UILabel!
    @IBOutlet weak var reminderBrief: UILabel!
    
    var reminder:PFObject!
    
    override func prepareForReuse() {
        contactImage.image = defaultContactImage
    }
    
    override func awakeFromNib() {
        contactImage.layer.cornerRadius = contactImage.frame.size.height/2
        contactImage.layer.masksToBounds = true
        contactImage.layer.borderWidth = 0
    }
    
    
    func fillCellWith(contact:Contact, reminder:PFObject){
        if let image = contact.image {
            contactImage.image = contact.image
        }
        contactName.text = contact.name
        let cardItems = reminder[kReminderCardItems] as [AnyObject]
        reminderBrief.text =  "\(cardItems.count) items"
    }
    
}

var templateItemCell:ReminderItemTableViewCell!
let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)


class RemindersTableViewController:UITableViewController,UISearchDisplayDelegate{
    @IBOutlet weak var searchBar: UISearchBar!
    var contactsHelper = ContactsHelper()
    var reminderCards:[ReminderCard] = []
    var searchResults:[NSDictionary] = []
    
    var reminderManager = UDOReminderManager.sharedInstance
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2"))
        templateItemCell = reminderItemCellNib.instantiateWithOwner(nil, options: nil)[0] as ReminderItemTableViewCell
        templateItemCell.frame = CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: 44)
        templateItemCell.layoutIfNeeded()
        if (PFUser.currentUser() != nil ) {
            self.userLoggedIn()
        }
    }
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
        /*
        if unwindSegue.identifier == "TaskSave" {
        var frontCard = collectionView.cellForItemAtIndexPath(exposedItemIndexPath) as ReminderCardViewCell
        let taskViewController:TaskEditViewController = unwindSegue.sourceViewController as TaskEditViewController
        frontCard.saveCardItemFrom(taskEditViewController: taskViewController)
        
        }else */
        if unwindSegue.identifier == "Loggedin"{
            self.userLoggedIn()
        }else if unwindSegue.identifier == "ContactSelected"{
            let contactDetailsVC = unwindSegue.sourceViewController as ContactDetailsViewController
            addReminderCardForContact(contactDetailsVC.contact, numberIndex: contactDetailsVC.tableView.indexPathForSelectedRow()!.row)
        }
    }
    
    func addReminderCardForContact(contact:Contact,numberIndex: Int){
        var found = false
        let userId = contact.numbers[numberIndex].userId!
        for var index = 0; index < reminderCards.count; ++index {
            let card = reminderCards[index]
            if card.owners.count == 2 {
                //not a group
                for owner in card.owners{
                    if owner == userId {
                        let indexPath = NSIndexPath(forItem: index, inSection: 0)
                        self.performSegueWithIdentifier("ShowReminderCard", sender: card)
                        found = true
                        break
                    }
                }
            }
        }
        if !found {
            createReminderCardForUserId(userId)
        }
    }
    
    func createReminderCardForUserId(userId:String){
        var card = ReminderCard()
        card.owners = [PFUser.currentUser().username, userId]
        card[kReminderCardItems] = []
        reminderCards.insert(card, atIndex: 0)
        self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Automatic)
        card.saveInBackground()
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowReminderCard"{
            let reminderCardTVC = segue.destinationViewController as ReminderCardTableViewController
            let card = sender as ReminderCard
            reminderCardTVC.contactHelper = self.contactsHelper
            reminderCardTVC.reminderCard = card
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
        self.performSegueWithIdentifier("ShowContacts", sender: nil)
    }
    
    func userLoggedIn(){
        self.contactsHelper.authorize({ () -> Void in
            let cardQuery = PFQuery(className:kReminderCardClassName)
            cardQuery.whereKey(kReminderCardCollaborators,equalTo:PFUser.currentUser().username)
            cardQuery.findObjectsInBackgroundWithBlock({
                (cards:[AnyObject]!, error: NSError!) -> Void in
                if error == nil{
                    self.reminderCards = cards as [ReminderCard]
                    self.sortAndReloadReminders()
                    self.reminderManager.requestAccess { (granted:Bool, error:NSError!) -> Void in
                        if !granted {
                            UIAlertView(title: "Error", message: "u.do need access to reminders in order to work!", delegate: nil, cancelButtonTitle: "Okay").show()
                            return
                        }
                        self.reminderManager.mergeReminders(self.reminderCards)
                    }
                }else{
                    //handle error
                    println("getReminders: \(error)")
                }
                
            })
            }, fail: { () -> Void in
                UIAlertView(title: "Error", message: "Contacts access failed!", delegate: nil, cancelButtonTitle: nil).show()
                return
        })
    }
    
    func sortAndReloadReminders(){
        self.reminderCards.sort({ (c1:PFObject, c2:PFObject) -> Bool in
            return c1.updatedAt.compare(c2.updatedAt) == NSComparisonResult.OrderedDescending
        })
        self.tableView.reloadData()
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if self.tableView == tableView{
            return self.tableView.rowHeight
        }else{
            //search
            let itemText = searchResults[indexPath.row][kReminderItemDescription] as String
            return max(templateItemCell.cellHeightThatFitsForItemText(itemText),44)
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.tableView == tableView {
            return reminderCards.count
        }else{
            //search
            return searchResults.count
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if self.tableView == tableView {
            var reminderCell = tableView.dequeueReusableCellWithIdentifier("ReminderCell", forIndexPath: indexPath) as ReminderTableViewCell
            let reminder = self.reminderCards[indexPath.row]
            let contact = contactForIndexPath(indexPath)
            println(reminder.owners)
            reminderCell.fillCellWith(contact, reminder: reminder)
            return reminderCell
        }else{
            //search
            let itemCell:ReminderItemTableViewCell = tableView.dequeueReusableCellWithIdentifier("ReminderItemCell",forIndexPath: indexPath) as ReminderItemTableViewCell
            itemCell.initForSearchResults(searchResults[indexPath.row])
            return itemCell
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if self.tableView == tableView{
            self.performSegueWithIdentifier("ShowReminderCard", sender: reminderCards[indexPath.row])
        }else{
            let selectedSearchResult = self.searchResults[indexPath.row]
            let reminderCard = selectedSearchResult["reminderCard"] as PFObject
            self.performSegueWithIdentifier("ShowReminderCard", sender: reminderCard)
        }
    }
    
    func contactForIndexPath(indexPath:NSIndexPath) -> Contact {
        let reminder = reminderCards[indexPath.row]
        return contactsHelper.getContactForUserId(GetOtherUsernameFor(reminder: reminder))
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, didLoadSearchResultsTableView tableView: UITableView!) {
        let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)
        tableView.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderItemCell")
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, shouldReloadTableForSearchString searchString: String!) -> Bool {
        var newSearchResults:[NSDictionary] = []
        for var cardIndex = 0; cardIndex < self.reminderCards.count; ++cardIndex{
            let card = self.reminderCards[cardIndex]
            for item in card[kReminderCardItems] as [NSDictionary]{
                let description = item[kReminderItemDescription] as NSString
                for token in description.componentsSeparatedByString(" ") as [String]{
                    if token.lowercaseString.hasPrefix(searchString.lowercaseString){
                        var itemSearchResult = NSMutableDictionary(dictionary: item)
                        itemSearchResult["reminderName"] = self.contactsHelper.getContactForUserId(GetOtherUsernameFor(reminder: card)).name
                        itemSearchResult["reminderCard"] = card
                        newSearchResults.append(itemSearchResult)
                        break
                    }
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