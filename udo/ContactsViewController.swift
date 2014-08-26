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


class ContactTableViewCell:UITableViewCell{
    @IBOutlet weak var name: UILabel!
    
}

class ContactPhoneNumberTableViewCell:UITableViewCell{
    @IBOutlet weak var number: UILabel!
    @IBOutlet weak var isRegisteredImageView: UIImageView!
    @IBOutlet weak var inviteButton: UIButton!
    
}

class ContactNumber{
    var original:String!
    var userId:String?
    var isRegistered = false
}

class Contact{
    var name:String!
    var numbers:[ContactNumber] = []
    init(){
        
    }
}

class ContactDetailsViewController:UITableViewController{
    @IBOutlet weak var name: UILabel!
    
    var contact:Contact!
    
    override func viewDidLoad() {
        name.text = contact.name
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
    var phoneUtil:NBPhoneNumberUtil! = NBPhoneNumberUtil.sharedInstance()
    var addressBook: ABAddressBookRef?
    var contacts:[Contact] = []
    var searchResults:[Contact] = []
    
    override func viewDidLoad() {
        if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.NotDetermined) {
            var errorRef: Unmanaged<CFError>? = nil
            addressBook = extractABAddressBookRef(ABAddressBookCreateWithOptions(nil, &errorRef))
            ABAddressBookRequestAccessWithCompletion(addressBook, { success, error in
                if success {
                    self.contactsAuthorized()
                }
                else {
                    println("ContactsViewController: \(error)")
                    self.navigationController.dismissViewControllerAnimated(true, completion: nil)
                }
            })
        }
        else if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Denied || ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Restricted) {
            self.navigationController.dismissViewControllerAnimated(true, completion: nil)
        }
        else if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Authorized) {
            self.contactsAuthorized()
        }
        
    }
    
    func extractABAddressBookRef(abRef: Unmanaged<ABAddressBookRef>!) -> ABAddressBookRef? {
        if let ab = abRef {
            return Unmanaged<NSObject>.fromOpaque(ab.toOpaque()).takeUnretainedValue()
        }
        return nil
    }
    
    func updateContactsWithAppUserIds(userIds:[String]) {
        //there should be a more cpu efficient way of doing this!
        for contact in contacts{
            for number in contact.numbers{
                for userId in userIds{
                    if number.userId == userId {
                        number.isRegistered = true
                    }
                }
            }
        }
    }
    
    func getAppUsers(){
        let user = PFUser.currentUser()
        let userCountryCode = user["country"] as NSNumber
        let userRegionCode = phoneUtil.getRegionCodeForCountryCode(userCountryCode)
        var numbers:[String] = []
        var error:NSError?
        for contact in contacts{
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
    
    func convertPhoneNumberToUserId(phoneNumber:String) -> String? {
        let user = PFUser.currentUser()
        let userCountryCode = user["country"] as NSNumber
        let userRegionCode = phoneUtil.getRegionCodeForCountryCode(userCountryCode)
        var error:NSError?
        let nbPhoneNumber:NBPhoneNumber = phoneUtil.parse(phoneNumber, defaultRegion: userRegionCode, error: &error)
        if error == nil {
            return phoneUtil.format(nbPhoneNumber, numberFormat: NBEPhoneNumberFormatE164, error: &error)
        }
        return nil
    }
    
    
    func contactsAuthorized() {
        var errorRef: Unmanaged<CFError>?
        addressBook = extractABAddressBookRef(ABAddressBookCreateWithOptions(nil, &errorRef))
        var contactList: NSArray = ABAddressBookCopyArrayOfAllPeople(addressBook).takeRetainedValue()
        for record:ABRecordRef in contactList {
            var contact = Contact()
            contact.name = ABRecordCopyCompositeName(record).takeRetainedValue() as NSString
            let uPhoneNumbers = ABRecordCopyValue(record, kABPersonPhoneProperty)
            let phones: ABMultiValueRef =
            Unmanaged<NSObject>.fromOpaque(uPhoneNumbers.toOpaque()).takeUnretainedValue() as ABMultiValueRef
            for (var i = 0; i < ABMultiValueGetCount(phones); ++i)
            {
                var uPhoneNumber = ABMultiValueCopyValueAtIndex(phones, i)
                let phoneNumber: String = Unmanaged<NSObject>.fromOpaque(
                    uPhoneNumber.toOpaque()).takeUnretainedValue() as String
                var contactNumber = ContactNumber()
                contactNumber.original = phoneNumber
                contactNumber.userId = convertPhoneNumberToUserId(phoneNumber)
                contact.numbers.append(contactNumber)
            }
            contacts.append(contact)
        }
        contacts.sort { $0.name < $1.name }
        self.getAppUsers()
        self.tableView.reloadData()
    }
    
    override func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        if tableView != self.tableView {
            return searchResults.count
        }else{
            return contacts.count
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
            let contact = contacts[indexPath.row]
            contactCell.name.text = contact.name
            return contactCell

        }
    }
    
    override func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        var selectedContact:Contact
        if tableView != self.tableView{
            //search
            selectedContact = searchResults[indexPath.row]
        }else{
            selectedContact = contacts[indexPath.row]
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
        for contact in contacts {
            let name:NSString = contact.name
            for token in name.componentsSeparatedByString(" ") as [String]{
                if token.lowercaseString.hasPrefix(searchString.lowercaseString){
                    newSearchResults.append(contact)
                }
            }
        }
        let oldResultSet:NSSet = NSSet(array: searchResults)
        let newResultSet:NSSet = NSSet(array: newSearchResults)
        searchResults = newSearchResults
        return !oldResultSet.isEqualToSet(newResultSet)
    }
    
}

