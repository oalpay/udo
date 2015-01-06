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
    
    func initWithContact(contact:APContact) {
        if let name = contact.compositeName {
            self.name.text = name
        }else{
            self.name.text = ""
        }
    }
    
}

class ContactPhoneNumberTableViewCell:UITableViewCell{
    @IBOutlet weak var number: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
}


class ContactDetailsViewController:UITableViewController{
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var image: UDContactImageView!
    
    var contact:APContact!
    var udContact:UDContact!
    var contactsManager = ContactsManager.sharedInstance
    
    override func viewDidLoad() {
        if let name = self.contact.compositeName {
            self.name.text = name
        }else {
            self.name.text = ""
        }
        self.image.layer.cornerRadius = image.frame.size.height/2
        self.image.layer.masksToBounds = true
        self.image.layer.borderWidth = 0
        
        if let image = self.contact.thumbnail {
            self.image.image = image
        }
        self.udContact = self.contactsManager.getUDContactsForAPcontact(self.contact).first
        self.image.loadWithContact(self.udContact, showIndicator: false)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowProfileImageView" {
            let profileImageVC = segue.destinationViewController as ProfileImageViewController
            profileImageVC.udContact = self.udContact
        }
    }
   
    @IBAction func imageViewPressed(sender: AnyObject) {
        if self.udContact != nil {
            self.performSegueWithIdentifier("ShowProfileImageView", sender: nil)
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let contactDetailsCell = tableView.dequeueReusableCellWithIdentifier("ContactDetails", forIndexPath: indexPath) as ContactPhoneNumberTableViewCell
        var number = self.contact.phones[indexPath.row] as String
        var contact = self.contactsManager.getUDContactForPhoneNumber(number)
        contactDetailsCell.number.text = number
        contactDetailsCell.actionButton.addTarget(self, action: "inviteButtonPreseed:", forControlEvents: UIControlEvents.TouchUpInside)
        if self.contactsManager.isUserRegistered(contact.userId) {
            contactDetailsCell.actionButton.setTitle("do", forState: UIControlState.Normal)
            contactDetailsCell.actionButton.setTitle("do", forState: UIControlState.Highlighted)
        }else{
            contactDetailsCell.actionButton.setTitle("invite", forState: UIControlState.Normal)
            contactDetailsCell.actionButton.setTitle("invite", forState: UIControlState.Highlighted)
        }
        return contactDetailsCell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.contact.phones.count
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
    
    var contacts:[APContact]!
    var previousSearchResultSet = NSSet()
    
    override func viewDidLoad() {
        self.navigationController?.navigationBar.titleTextAttributes =  [NSForegroundColorAttributeName: AppTheme.logoColor]
        self.contacts = contactsManager.contacts
        (self.sectionHeaders,self.sectionContacts)  = self.divideContactsToSection(self.contacts)
    }
    
    func divideContactsToSection( contacts:[APContact] ) -> ([String]!,Dictionary<String,NSMutableArray>!) {
        var sections = Dictionary<String,NSMutableArray>()
        for contact in contacts {
            var section:NSMutableArray!
            var sectionChar:String!
            if let name = contact.firstName as NSString?{
                if name.length > 0 {
                    sectionChar = name.substringToIndex(1)
                }
            }else {
                if let name = contact.compositeName as NSString?{
                    sectionChar = name.substringToIndex(1)
                }
            }
            if sectionChar == nil {
                sectionChar = ""
            }
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
            if let section = self.searchSections[self.searchHeaders[indexPath.section]] {
                let contact = section.objectAtIndex(indexPath.row) as APContact
                if let name = contact.compositeName {
                    contactCell.textLabel?.text = name
                }else{
                    contactCell.textLabel?.text = ""
                }
                contactCell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            }
            return contactCell
        }else{
            var contactCell = tableView.dequeueReusableCellWithIdentifier("ContactCell", forIndexPath: indexPath) as ContactTableViewCell
            if let section = sectionContacts[sectionHeaders[indexPath.section]] {
                let contact = section.objectAtIndex(indexPath.row) as APContact
                contactCell.initWithContact(contact)
            }
            return contactCell
            
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var selectedContact:APContact!
        if tableView != self.tableView{
            //search
            if let section = self.searchSections[self.searchHeaders[indexPath.section]]{
                selectedContact = section.objectAtIndex(indexPath.row) as APContact
            }
        }else{
            if let section  = sectionContacts[sectionHeaders[indexPath.section]]{
                selectedContact = section.objectAtIndex(indexPath.row) as APContact
            }
        }
        if selectedContact == nil {
            return
        }
        performSegueWithIdentifier("ShowContactDetail", sender: selectedContact)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowContactDetail"{
            let contact = sender as APContact
            let contactDetailsVC = segue.destinationViewController as ContactDetailsViewController
            contactDetailsVC.contact = contact
        }
    }
    
     var predicate = NSPredicate(format: "(firstName BEGINSWITH[cd] $searchString) OR (lastName BEGINSWITH[cd] $searchString) OR (compositeName BEGINSWITH[cd] $searchString)")!
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String) -> Bool {
        var nsContacts = self.contacts as NSArray
        var newSearchResults = nsContacts.filteredArrayUsingPredicate(predicate.predicateWithSubstitutionVariables(["searchString": searchString])!) as [APContact]
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

