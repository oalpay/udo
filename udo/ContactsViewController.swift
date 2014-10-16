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
    
    
    
    func initWithContact(contact:Contact) {
        self.name.text = contact.name
    }
    
}

class ContactPhoneNumberTableViewCell:UITableViewCell{
    @IBOutlet weak var number: UILabel!
    @IBOutlet weak var isRegisteredImageView: UIImageView!
    @IBOutlet weak var inviteButton: UIButton!
    
}


class ContactDetailsViewController:UITableViewController{
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var image: UIImageView!
    
    var contact:Contact!
    var contactsManager = ContactsManager.sharedInstance
    
    override func viewDidLoad() {
        name.text = contact.name
        image.layer.cornerRadius = image.frame.size.height/2
        image.layer.masksToBounds = true
        image.layer.borderWidth = 0
        if let img = contact.image{
            image.image = img
        }
    }
   
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let contactDetailsCell = tableView.dequeueReusableCellWithIdentifier("ContactDetails", forIndexPath: indexPath) as ContactPhoneNumberTableViewCell
        let number = contact.numbers[indexPath.row]
        contactDetailsCell.number.text = number.original
        contactDetailsCell.inviteButton.addTarget(self, action: "inviteButtonPreseed:", forControlEvents: UIControlEvents.TouchUpInside)
        if contactsManager.isNumberRegistered(number) {
            contactDetailsCell.isRegisteredImageView.hidden = false
            contactDetailsCell.inviteButton.hidden = true
        }else{
            contactDetailsCell.isRegisteredImageView.hidden = true
            contactDetailsCell.inviteButton.hidden = false
            
        }
        return contactDetailsCell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contact.numbers.count
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("ContactSelected", sender: self)
    }
    
    func inviteButtonPreseed(button:UIButton){
        var point = button.convertPoint(CGPointZero, toView:self.tableView)
        if let indexPath =  self.tableView.indexPathForRowAtPoint(point) {
            self.tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: UITableViewScrollPosition.None)
            self.performSegueWithIdentifier("ContactSelected", sender: self)
        }
    }
}

class ContactsViewController:UITableViewController,UISearchDisplayDelegate{
    var contactsManager = ContactsManager.sharedInstance
    var sectionHeaders:[String]!
    var sectionContacts:Dictionary<String,NSMutableArray>!
    
    var searchHeaders:[String]! = []
    var searchSections:Dictionary<String,NSMutableArray>! = Dictionary<String,NSMutableArray>()
    
    var contacts:[Contact]!
    var previousSearchResultSet = NSSet()
    
    override func viewDidLoad() {
        self.navigationController?.navigationBar.titleTextAttributes =  [NSForegroundColorAttributeName: AppTheme.logoColor]
        self.contacts = contactsManager.contacts
        (self.sectionHeaders,self.sectionContacts)  = self.divideContactsToSection(self.contacts)
    }
    
    func divideContactsToSection( contacts:[Contact] ) -> ([String]!,Dictionary<String,NSMutableArray>!) {
        var sections = Dictionary<String,NSMutableArray>()
        for contact in contacts{
            var section:NSMutableArray!
            let sectionChar = contact.name!.substringToIndex(contact.name!.startIndex.successor()).uppercaseString
            if let s = sections[sectionChar] as NSMutableArray?{
                section = s
            }else{
                section = NSMutableArray()
                sections[sectionChar] = section
            }
            section.addObject(contact)
        }
        var headers = sections.keys.array.sorted{ (n1:String, n2:String) -> Bool in
            return n1.compare(n2, options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil, locale: nil) == NSComparisonResult.OrderedAscending
        }
        return (headers, sections)
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if tableView != self.tableView {
            return self.searchHeaders.count
        }else{
            return self.sectionHeaders.count
        }
    }
    
    override func sectionIndexTitlesForTableView(tableView: UITableView) -> [AnyObject]! {
        if tableView != self.tableView {
            return self.searchHeaders
        }else{
            return self.sectionHeaders
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String {
        if tableView != self.tableView {
            return self.searchHeaders[section]
        }else{
            return self.sectionHeaders[section]
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView != self.tableView {
            let s = self.searchHeaders[section]
            return self.searchSections[s]!.count
        }else{
            let s = self.sectionHeaders[section]
            return self.sectionContacts[s]!.count
        }
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 44
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if tableView != self.tableView{
            //searching
            var contactCell = tableView.dequeueReusableCellWithIdentifier("Cell") as UITableViewCell!
            if (contactCell == nil) {
                contactCell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "Cell")
            }
            let section = self.searchSections[self.searchHeaders[indexPath.section]]
            let contact = section?.objectAtIndex(indexPath.row) as Contact
            contactCell.textLabel?.text = contact.name
            contactCell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            return contactCell
        }else{
            var contactCell = tableView.dequeueReusableCellWithIdentifier("ContactCell", forIndexPath: indexPath) as ContactTableViewCell
            let section = sectionContacts[sectionHeaders[indexPath.section]]
            let contact = section?.objectAtIndex(indexPath.row) as Contact
            contactCell.initWithContact(contact)
            return contactCell
            
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var selectedContact:Contact
        if tableView != self.tableView{
            //search
            let section = self.searchSections[self.searchHeaders[indexPath.section]]
            selectedContact = section?.objectAtIndex(indexPath.row) as Contact
        }else{
            let section = sectionContacts[sectionHeaders[indexPath.section]]
            selectedContact = section?.objectAtIndex(indexPath.row) as Contact
        }
        performSegueWithIdentifier("ShowContactDetail", sender: selectedContact)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowContactDetail"{
            let contact = sender as Contact
            let contactDetailsVC = segue.destinationViewController as ContactDetailsViewController
            contactDetailsVC.contact = contact
        }
    }
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String) -> Bool {
        var newSearchResults:[Contact] = []
        var lowercaseSearchString = searchString.lowercaseString
        for contact in self.contacts {
            for token in contact.tokens {
                if token.hasPrefix(lowercaseSearchString) {
                    newSearchResults.append(contact)
                    break
                }
            }
        }
        let newResultSet:NSSet = NSSet(array: newSearchResults)
        if self.previousSearchResultSet.isEqualToSet(newResultSet){
            return false
        }else{
            self.previousSearchResultSet = newResultSet
            (self.searchHeaders, self.searchSections) = self.divideContactsToSection(newSearchResults)
            return true
        }
    }
    
}

