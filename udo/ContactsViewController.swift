//
//  ContactsViewController.swift
//  udo
//
//  Created by Osman Alpay on 31/07/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import UIKit
import AddressBookUI
import MessageUI

var appstoreUrl:String = ""


class ContactTableViewCell:UITableViewCell{
    @IBOutlet weak var name: UILabel!
    
    
    
    func initWithContact(contact:Contact) {
        self.name.text = contact.name
    }
    
}

class ContactPhoneNumberTableViewCell:UITableViewCell{
    @IBOutlet weak var number: UILabel!
    @IBOutlet weak var isRegisteredImageView: UIImageView!
    @IBOutlet weak var inviteButton: UIButton!
    
}


class ContactDetailsViewController:UITableViewController,MFMessageComposeViewControllerDelegate{
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var image: UIImageView!
    
    
    var contact:Contact!
    
    override func viewDidLoad() {
        name.text = contact.name
        image.layer.cornerRadius = image.frame.size.height/2
        image.layer.masksToBounds = true
        image.layer.borderWidth = 0
        if let img = contact.image{
            image.image = img
        }
        
    }
    
    
    @IBAction func inviteButtonPressed(sender: AnyObject) {
        let point = sender.convertPoint(CGPointZero, toView: self.tableView)
        let indexPath = self.tableView.indexPathForRowAtPoint(point)
        self.tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: UITableViewScrollPosition.Bottom)
        sendInvitation()
    }
    
    func sendInvitation(){
        if MFMessageComposeViewController.canSendText() {
            let selectedNumber = contact.numbers[self.tableView.indexPathForSelectedRow().row]
            let recipents = [selectedNumber.original]
            let messageController = MFMessageComposeViewController()
            messageController.messageComposeDelegate = self
            messageController.recipients = recipents
            messageController.body = "I sent you an reminder. \(appstoreUrl)"
            self.presentViewController(messageController, animated: true, completion: nil)
        }else{
            let selectedNumber = contact.numbers[self.tableView.indexPathForSelectedRow().row]
            invitationSent(selectedNumber)
            self.performSegueWithIdentifier("ContactSelected", sender: nil)
        }
    }
    
    func invitationSent(number:ContactNumber){
        var invitation = PFObject(className: "Invitation")
        invitation["to"] = number.userId
        invitation["from"] = PFUser.currentUser().username
        invitation.saveInBackground()
    }
    
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        if result.value == MessageComposeResultFailed.value{
            UIAlertView(title: "Error", message: "Failed to send message", delegate: nil, cancelButtonTitle: "Continue").show()
            controller.dismissViewControllerAnimated(true, completion: nil)
        }else if result.value == MessageComposeResultSent.value {
            let selectedNumber = contact.numbers[self.tableView.indexPathForSelectedRow().row]
            invitationSent(selectedNumber)
            controller.dismissViewControllerAnimated(true, completion: nil)
            self.performSegueWithIdentifier("ContactSelected", sender: nil)
        }else if result.value == MessageComposeResultCancelled.value {
            controller.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    override func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let contactDetailsCell = tableView.dequeueReusableCellWithIdentifier("ContactDetails", forIndexPath: indexPath) as ContactPhoneNumberTableViewCell
        let number = contact.numbers[indexPath.row]
        contactDetailsCell.number.text = number.original
        if number.isRegistered {
            contactDetailsCell.isRegisteredImageView.hidden = false
            contactDetailsCell.inviteButton.hidden = true
        }else{
            contactDetailsCell.isRegisteredImageView.hidden = true
            contactDetailsCell.inviteButton.hidden = false
            
        }
        return contactDetailsCell
    }
    
    override func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return contact.numbers.count
    }
    
    override func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        let selectedNumber = contact.numbers[self.tableView.indexPathForSelectedRow().row]
        if selectedNumber.isRegistered{
            self.performSegueWithIdentifier("ContactSelected", sender: self)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        if segue.identifier == "ContactSelected"{
            let remindersCVC = segue.destinationViewController as RemindersCollectionViewController
            let selectedNumber = contact.numbers[self.tableView.indexPathForSelectedRow().row]
            remindersCVC.addReminderCardForUserId(selectedNumber.userId!, contact: contact)
        }
    }
    
}

class ContactsViewController:UITableViewController,UISearchDisplayDelegate{
    var contactsHelper:ContactsHelper!
    var sectionHeaders:[String] = []
    var sectionContacts = Dictionary<String,NSMutableArray>()
    var searchResults:[Contact] = []
    
    override func viewDidLoad() {
        self.divideContactsToSection()
        self.getAppUsers()
    }
    
    func divideContactsToSection(){
        for contact in contactsHelper.contacts{
            var section:NSMutableArray!
            let sectionChar = contact.name.substringToIndex(contact.name.startIndex.successor()).uppercaseString
            if let s = sectionContacts[sectionChar] as NSMutableArray?{
                section = s
            }else{
                section = NSMutableArray()
                sectionContacts[sectionChar] = section
            }
            section.addObject(contact)
        }
        self.sectionHeaders = sectionContacts.keys.array.sorted{ (n1:String, n2:String) -> Bool in
            return n1.compare(n2, options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil, locale: nil) == NSComparisonResult.OrderedAscending
        }
    }
    
    func updateContactsWithAppUserIds(userIds:[String]) {
        //there should be a more cpu efficient way of doing this!
        for contact in contactsHelper.contacts{
            for number in contact.numbers{
                for userId in userIds{
                    if number.userId == userId {
                        number.isRegistered = true
                    }
                }
            }
        }
        self.tableView.reloadData()
    }
    
    func getAppUsers(){
        var numbers:[String] = []
        for contact in contactsHelper.contacts{
            for number in contact.numbers{
                if let userId = number.userId{
                    numbers.append(userId)
                }
            }
        }
        var params = Dictionary<String,AnyObject>()
        params["numbers"] = numbers
        PFCloud.callFunctionInBackground("appUsers", withParameters:params) {
            (result: AnyObject!, error: NSError!) -> Void in
            if error == nil {
                self.updateContactsWithAppUserIds(result as [String])
            }
        }
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return self.sectionHeaders.count
    }
    
    override func sectionIndexTitlesForTableView(tableView: UITableView!) -> [AnyObject]! {
        return self.sectionHeaders
    }
    
    override func tableView(tableView: UITableView!, titleForHeaderInSection section: Int) -> String! {
        return self.sectionHeaders[section]
    }
    
    override func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        if tableView != self.tableView {
            return searchResults.count
        }else{
            let s = sectionHeaders[section]
            return sectionContacts[s]!.count
        }
    }
    
    override func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        if tableView != self.tableView{
            //searching
            var contactCell = tableView.dequeueReusableCellWithIdentifier("Cell") as? UITableViewCell
            if (contactCell == nil) {
                contactCell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "Cell")
            }
            let contact = searchResults[indexPath.row]
            contactCell?.textLabel.text = contact.name
            contactCell?.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            return contactCell
        }else{
            var contactCell = tableView.dequeueReusableCellWithIdentifier("ContactCell", forIndexPath: indexPath) as ContactTableViewCell
            let section = sectionContacts[sectionHeaders[indexPath.section]]
            let contact = section?.objectAtIndex(indexPath.row) as Contact
            contactCell.initWithContact(contact)
            return contactCell
            
        }
    }
    
    override func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        var selectedContact:Contact
        if tableView != self.tableView{
            //search
            selectedContact = searchResults[indexPath.row]
        }else{
            let section = sectionContacts[sectionHeaders[indexPath.section]]
            selectedContact = section?.objectAtIndex(indexPath.row) as Contact
        }
        performSegueWithIdentifier("ShowContactDetail", sender: selectedContact)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        if segue.identifier == "ShowContactDetail"{
            let contact = sender as Contact
            let contactDetailsVC = segue.destinationViewController as ContactDetailsViewController
            contactDetailsVC.contact = contact
        }
    }
    
    func searchDisplayController(controller: UISearchDisplayController!, shouldReloadTableForSearchString searchString: String!) -> Bool {
        var newSearchResults:[Contact] = []
        for contact in contactsHelper.contacts {
            let name:NSString = contact.name
            for token in name.componentsSeparatedByString(" ") as [String]{
                if token.lowercaseString.hasPrefix(searchString.lowercaseString){
                    newSearchResults.append(contact)
                    break
                }
            }
        }
        let oldResultSet:NSSet = NSSet(array: searchResults)
        let newResultSet:NSSet = NSSet(array: newSearchResults)
        searchResults = newSearchResults
        return !oldResultSet.isEqualToSet(newResultSet)
    }
    
}

