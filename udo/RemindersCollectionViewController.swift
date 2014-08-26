//
//  FirstViewController.swift
//  udo
//
//  Created by Osman Alpay on 31/07/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import UIKit
import AddressBookUI

class RemindersHeader:UIView{
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var addReminderCardButton: UIButton!
    @IBOutlet weak var searchBarTrailingSpace: NSLayoutConstraint!
    
    @IBOutlet weak var searchResultsTV: UITableView!
    
    var cvc:RemindersCollectionViewController!
    
    class func kind()->String{
        return "RemindersHeader"
    }
    

    func initWithCVC( cvc:RemindersCollectionViewController){
        self.cvc = cvc
        var image = self.backgroundImageView.image.applyLightEffect()
        self.backgroundImageView.image = image

    }

    
    //search controller
    func searchBarTextDidBeginEditing(searchBar: UISearchBar!) {
        searchBar.showsCancelButton = true
        searchBarTrailingSpace.constant = 0
        self.cvc.collectionView.contentInset.top += self.cvc.collectionView.frame.height
    }
    
    func  searchBarCancelButtonClicked(searchBar: UISearchBar!) {
        searchBar.resignFirstResponder()
        searchBar.showsCancelButton = false
        searchBarTrailingSpace.constant = 60
        self.cvc.collectionView.contentInset.top -= self.cvc.collectionView.bounds.height
    }
    
}

class RemindersCollectionViewController: TGLStackedViewController, UICollectionViewDataSource,ABPeoplePickerNavigationControllerDelegate,UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate {
    
    var backgroundImg:UIImage!
    var reminderCards:[PFObject] = []
    var searchController:UISearchDisplayController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.exposedTopOverlap = 0
        self.exposedLayoutMargin = UIEdgeInsetsMake(20, 0.0, 0.0, 0.0);
        self.stackedLayout.layoutMargin = UIEdgeInsetsMake(65, 0.0, 0.0, 0.0);
        
        // Set to NO to prevent a small number
        // of cards from filling the entire
        // view height evenly and only show
        // their -topReveal amount
        //
        self.stackedLayout.fillHeight = false
        
        // Set to NO to prevent a small number
        // of cards from being scrollable and
        // bounce
        //
        self.stackedLayout.alwaysBounce = true
        
        // Set to NO to prevent unexposed
        // items at top and bottom from
        // being selectable
        //
        self.unexposedItemsAreSelectable = true
        
        self.stackedLayout.topReveal = 60
        
        var remindersHeaderNib = UINib(nibName: "RemindersHeader", bundle: nil)
        var remindersHeaderView = remindersHeaderNib.instantiateWithOwner(nil, options: nil)[0] as RemindersHeader
        remindersHeaderView.initWithCVC(self)
        self.collectionView.backgroundView  = remindersHeaderView
        
    }
    
    override func viewDidAppear(animated: Bool) {
        if (PFUser.currentUser() != nil) {
            self.userLoggedIn()
        } else {
            self.performSegueWithIdentifier("RegisterSegue", sender: self)
        }
    }
    
    override func initController() {
        super.initController()
        self.stackedLayout = UDOStackedLayout()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    /*
    override func collectionView(collectionView: UICollectionView!, viewForSupplementaryElementOfKind kind: String!, atIndexPath indexPath: NSIndexPath!) -> UICollectionReusableView! {
        var remindersHeader = collectionView.dequeueReusableSupplementaryViewOfKind(RemindersHeader.kind(), withReuseIdentifier: RemindersHeader.kind(), forIndexPath: indexPath) as RemindersHeader
        println(remindersHeader)
        if remindersHeader.initialiseOnce(){
            remindersHeader.addReminderCardButton.addTarget(self, action: "addReminderButtonCliced:", forControlEvents: UIControlEvents.TouchUpInside)
        }
        return remindersHeader
    }
    */
    override func collectionView(collectionView: UICollectionView!,
        numberOfItemsInSection section: Int) -> Int{
            return reminderCards.count
    }
    
    override func collectionView(collectionView: UICollectionView!,
        cellForItemAtIndexPath indexPath: NSIndexPath!) -> UICollectionViewCell!{
            
            let card:ReminderCardViewCell = collectionView.dequeueReusableCellWithReuseIdentifier("ReminderCard", forIndexPath: indexPath) as ReminderCardViewCell
            card.initReminderCard(reminderCards[indexPath.row])
            return card;
            
    }
    
    override func moveItemAtIndexPath(fromIndexPath:NSIndexPath, toIndexPath:NSIndexPath){
        
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        if segue.identifier == "TaskEdit" {
            if sender != nil {
                let reminderCardView = collectionView.cellForItemAtIndexPath(exposedItemIndexPath) as ReminderCardViewCell
                let navController = segue.destinationViewController as UINavigationController
                var taskController = navController.topViewController as TaskEditViewController
                let itemIndexPath = sender as NSIndexPath
                taskController.item = reminderCardView.cardItems[itemIndexPath.row] as NSDictionary
            }
        }
    }
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
        if unwindSegue.identifier == "TaskSave" {
            var frontCard = collectionView.cellForItemAtIndexPath(exposedItemIndexPath) as ReminderCardViewCell
            let taskViewController:TaskEditViewController = unwindSegue.sourceViewController as TaskEditViewController
            frontCard.saveCardItemFrom(taskEditViewController: taskViewController)
            
        }else if unwindSegue.identifier == "Login"{
            self.userLoggedIn()
        }
    }
    
    func userLoggedIn(){
        let query = PFQuery(className:"ReminderCard")
        query.whereKey("createdBy",equalTo:PFUser.currentUser())
        query.findObjectsInBackgroundWithBlock({
            (cards:[AnyObject]!, error: NSError!) -> Void in
            if error == nil{
                self.reminderCards = cards as [PFObject]
                self.collectionView.reloadData()
            }else{
                //handle error
                println("getReminders: \(error)")
            }
            
        })
    }
    
    func addReminderButtonCliced(sender: AnyObject) {
        self.performSegueWithIdentifier("ShowContacts", sender: self)
    }
    /*
    
    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController!, shouldContinueAfterSelectingPerson person: ABRecordRef!) -> Bool{
        return true
    }
    
    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController!, shouldContinueAfterSelectingPerson person: ABRecordRef!, property: ABPropertyID, identifier: ABMultiValueIdentifier) -> Bool {
        return true
    }
    
    func peoplePickerNavigationController( peoplePicker: ABPeoplePickerNavigationController!,
        person: ABRecordRef!,
        property: ABPropertyID,
        identifier: ABMultiValueIdentifier) -> Bool{
            return false
    }
    
    // Called after a property has been selected by the user.
    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController!, didSelectPerson person: ABRecordRef!, property: ABPropertyID, identifier: ABMultiValueIdentifier){
        /* Get all the phone numbers this user has */
        let unmanagedPhones = ABRecordCopyValue(person, property)
        let phones: ABMultiValueRef =
        Unmanaged.fromOpaque(unmanagedPhones.toOpaque()).takeUnretainedValue()
            as NSObject as ABMultiValueRef
        
        let unmanagedPhone = ABMultiValueCopyValueAtIndex(phones, ABMultiValueGetIndexForIdentifier(phones,identifier))
        let phone: String = Unmanaged.fromOpaque(
            unmanagedPhone.toOpaque()).takeUnretainedValue() as NSObject as String
        
        var phoneUtil:NBPhoneNumberUtil! = NBPhoneNumberUtil.sharedInstance()
        let user = PFUser.currentUser()
        let userCountryCode = user["country"] as NSNumber
        let userRegionCode = phoneUtil.getRegionCodeForCountryCode(userCountryCode)
        
        var error:NSError?
        let phoneNumber:NBPhoneNumber = phoneUtil.parse(phone, defaultRegion: userRegionCode, error: &error)
        if error == nil {
            let numberE164 = phoneUtil.format(phoneNumber, numberFormat: NBEPhoneNumberFormatE164, error: &error)
            if let e = error {
                // handle error
            }else{
                let contactName: String = ABRecordCopyCompositeName(person).takeRetainedValue() as NSString
                addReminderCardForPhoneNumber(numberE164, contactName: contactName)
            }
        }
        if let e = error {
            println("E:MainViewController:peoplePickerNavigationController:\(e.localizedDescription)")
        }
    }
    */
    func addReminderCardForUserId(userId:String,contact: Contact){
        var found = false
        for var index = 0; index < reminderCards.count; ++index {
            let card = reminderCards[index]
            if card["reminderTo"] as String == userId {
                let indexPath = NSIndexPath(forItem: index, inSection: 0)
                exposeCard(indexPath)
                found = true
                break
            }
        }
        if !found {
            createNewCardForPhoneNumber(userId, contact: contact)
        }
    }
    
    func createNewCardForPhoneNumber(userId:String,contact: Contact){
        var card = PFObject(className:"ReminderCard")
        card["reminderTo"] = userId
        card["createdBy"] = PFUser.currentUser()
        card["name"] = contact.name
        card["items"] = []
        card.saveInBackground()
        reminderCards.append(card)
        self.collectionView.insertItemsAtIndexPaths([NSIndexPath(forItem: reminderCards.count-1, inSection: 0)])
    }
    
    func exposeCard(indexPath: NSIndexPath){
        if indexPath.isEqual(self.exposedItemIndexPath){
            // Collapse currently exposed item
            //
            self.exposedItemIndexPath = nil;
            
        } else if (self.unexposedItemsAreSelectable || self.exposedItemIndexPath == nil) {
            // Expose new item, possibly collapsing
            // the currently exposed item
            //
            self.exposedItemIndexPath = indexPath
        }
    }
    
    override func scrollViewWillEndDragging(scrollView: UIScrollView!, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if targetContentOffset.memory.y > 0  && targetContentOffset.memory.y < self.stackedLayout.layoutMargin.top{
            if velocity.y > 0 {
                targetContentOffset.memory.y = self.stackedLayout.layoutMargin.top
            }else{
                targetContentOffset.memory.y = 0
            }
        }
    }

    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        return nil
    }
    
}

