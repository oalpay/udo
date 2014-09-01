//
//  FirstViewController.swift
//  udo
//
//  Created by Osman Alpay on 31/07/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import UIKit
import AddressBookUI

class RemindersCollectionViewController: TGLStackedViewController, UICollectionViewDataSource{
    
    var backgroundImg:UIImage!
    var reminderCards:[PFObject] = []
    var searchController:UISearchDisplayController!
    var contactsHelper = ContactsHelper()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.exposedTopOverlap = 0
        self.exposedLayoutMargin = UIEdgeInsetsMake(25, 0.0, 0.0, 0.0);
        self.stackedLayout.layoutMargin = UIEdgeInsetsMake(70, 0.0, 0.0, 0.0);
        
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
        
        if (PFUser.currentUser() != nil ) {
            self.userLoggedIn()
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if PFUser.currentUser() == nil{
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
    
    override func collectionView(collectionView: UICollectionView!,
        numberOfItemsInSection section: Int) -> Int{
            return reminderCards.count
    }
    
    override func collectionView(collectionView: UICollectionView!,
        cellForItemAtIndexPath indexPath: NSIndexPath!) -> UICollectionViewCell!{
            
            let card:ReminderCardViewCell = collectionView.dequeueReusableCellWithReuseIdentifier("ReminderCard", forIndexPath: indexPath) as ReminderCardViewCell
            let contact = contactsHelper.getContactForUserId(reminderCards[indexPath.row][kReminderCardOwner] as String)
            card.initReminderCard(reminderCards[indexPath.row],ownerContact: contact)
            return card;
    }
    
    override func collectionView(collectionView: UICollectionView!, didSelectItemAtIndexPath indexPath: NSIndexPath!) {
        if self.exposedItemIndexPath != nil && indexPath == self.exposedItemIndexPath{
            let card = collectionView.cellForItemAtIndexPath(indexPath) as ReminderCardViewCell
            card.stackted()
        }else{
            let card = collectionView.cellForItemAtIndexPath(indexPath) as ReminderCardViewCell
            card.exposed()
        }
        super.collectionView(collectionView, didSelectItemAtIndexPath: indexPath)
    }
    
    override func canMoveItemAtIndexPath(indexPath: NSIndexPath!) -> Bool {
        return false
    }
    
    override func moveItemAtIndexPath(fromIndexPath:NSIndexPath, toIndexPath:NSIndexPath){
        
    }
    
    func deleteReminderCard(card:PFObject){
        self.exposedItemIndexPath = nil;
        for var i = 0;i < reminderCards.count;++i {
            if reminderCards[i] == card{
                card.deleteInBackground()
                reminderCards.removeAtIndex(i)
                self.collectionView.deleteItemsAtIndexPaths([NSIndexPath(forItem: i, inSection: 0)])
                break;
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        if segue.identifier == "ShowItemDetail" {
            if sender != nil {
                let reminderCardView = collectionView.cellForItemAtIndexPath(exposedItemIndexPath) as ReminderCardViewCell
                let navController = segue.destinationViewController as UINavigationController
                var taskController = navController.topViewController as TaskEditViewController
                let itemIndexPath = sender as NSIndexPath
                taskController.item = reminderCardView.cardItems[itemIndexPath.row] as NSDictionary
            }
        }else if segue.identifier == "ShowContacts"{
            let navC = segue.destinationViewController as UINavigationController
            let contactsVC = navC.topViewController as  ContactsViewController
            contactsVC.contactsHelper = self.contactsHelper
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
    func sortAndReloadReminders(){
        self.reminderCards.sort({ (c1:PFObject, c2:PFObject) -> Bool in
            return c1.updatedAt.compare(c2.updatedAt) == NSComparisonResult.OrderedDescending
        })
        self.collectionView.reloadData()
    }
    func userLoggedIn(){
        self.contactsHelper.authorize({ () -> Void in
            let query = PFQuery(className:"ReminderCard")
            query.whereKey(kReminderCardCreator,equalTo:PFUser.currentUser())
            query.findObjectsInBackgroundWithBlock({
                (cards:[AnyObject]!, error: NSError!) -> Void in
                if error == nil{
                    self.reminderCards = cards as [PFObject]
                    self.sortAndReloadReminders()
                }else{
                    //handle error
                    println("getReminders: \(error)")
                }
                
            })
            }, fail: { () -> Void in
                UIAlertView(title: "Error", message: "Contacts access failed!", delegate: nil, cancelButtonTitle: nil).show()
                return
        })
        let appstoreLinkQuery = PFQuery(className:"AppstoreLink")
        appstoreLinkQuery.findObjectsInBackgroundWithBlock { (urls:[AnyObject]!, error:NSError!) -> Void in
            if error == nil{
                appstoreUrl = urls[0]["url"] as String
            }
        }
    }
    
    func addReminderButtonCliced(sender: AnyObject) {
        self.performSegueWithIdentifier("ShowContacts", sender: self)
    }
    
    func addReminderCardForUserId(userId:String,contact: Contact){
        var found = false
        for var index = 0; index < reminderCards.count; ++index {
            let card = reminderCards[index]
            if card["owner"] as String == userId {
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
    
    func createNewCardForPhoneNumber(toUserId:String,contact: Contact){
        var card = PFObject(className:"ReminderCard")
        card[kReminderCardOwner] = toUserId
        card[kReminderCardCreator] = PFUser.currentUser()
        card[kReminderCardItems] = []
        reminderCards.append(card)
        self.collectionView.insertItemsAtIndexPaths([NSIndexPath(forItem: reminderCards.count-1, inSection: 0)])
        card.saveInBackgroundWithBlock { (succeeded:Bool, e:NSError!) -> Void in
            self.sortAndReloadReminders()
        }
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
    
    
}

