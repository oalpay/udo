//
//  RemindersHeader.swift
//  udo
//
//  Created by Osman Alpay on 27/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class RemindersHeader:UIView,UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate{
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var addReminderCardButton: UIButton!
    @IBOutlet weak var searchBarTrailingSpace: NSLayoutConstraint!
    @IBOutlet weak var searchResultsTV: UITableView!
    
    var searchResults:[NSDictionary] = []
    var templateCell:ReminderItemTableViewCell!
    
    var remindersCVC:RemindersCollectionViewController!
    
    
    func initWithCVC( cvc:RemindersCollectionViewController){
        self.remindersCVC = cvc
        var image = self.backgroundImageView.image.applyLightEffect()
        self.backgroundImageView.image = image
        searchResultsTV.hidden = true
        searchResultsTV.backgroundColor = UIColor(patternImage: UIImage(named: "geometry2"))
        let reminderItemCellNib = UINib(nibName: "ReminderItemCell", bundle: nil)
        searchResultsTV.registerNib(reminderItemCellNib, forCellReuseIdentifier: "ReminderItemCell")
        templateCell = reminderItemCellNib.instantiateWithOwner(nil, options: nil)[0] as ReminderItemTableViewCell
        templateCell.frame = CGRect(x: 0, y: 0, width: self.searchResultsTV.frame.width, height: 44)
        templateCell.layoutIfNeeded()
    }

    @IBAction func addButtonPressed(sender: AnyObject) {
        remindersCVC.addReminderButtonCliced(sender)
    }
    
    //search controller
    
    func searchBar(searchBar: UISearchBar!, textDidChange searchText: String!) {
        var newSearchResults:[NSDictionary] = []
        for var cardIndex = 0; cardIndex < self.remindersCVC.reminderCards.count; ++cardIndex{
            let card = self.remindersCVC.reminderCards[cardIndex]
            for item in card[kReminderCardItems] as [NSDictionary]{
                let description = item[kReminderItemDescription] as NSString
                for token in description.componentsSeparatedByString(" ") as [String]{
                    if token.lowercaseString.hasPrefix(searchBar.text.lowercaseString){
                        var itemSearchResult = NSMutableDictionary(dictionary: item)
                        itemSearchResult["reminderName"] = remindersCVC.contactsHelper.getContactForUserId(card[kReminderCardOwner] as  String).name
                        itemSearchResult["cardIndex"] = cardIndex
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
            self.searchResultsTV.reloadData()
        }
    }
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar!) {
        searchBar.showsCancelButton = true
        self.layoutIfNeeded()
        UIView.animateWithDuration( 0.2,{ () -> Void in
            self.searchBarTrailingSpace.constant = 0
            self.layoutIfNeeded()
        })
        hideRemindersCVC()
    }
    
    func hideRemindersCVC(){
        self.remindersCVC.collectionView.contentInset.top += self.remindersCVC.collectionView.frame.height
        searchResultsTV.hidden = false
        self.remindersCVC.collectionView.scrollEnabled = false
    }
    
    func  searchBarCancelButtonClicked(searchBar: UISearchBar!) {
        searchBar.resignFirstResponder()
        searchBar.showsCancelButton = false
        //self.layoutIfNeeded()
        UIView.animateWithDuration( 0.2,{ () -> Void in
            self.searchBarTrailingSpace.constant = 50
            self.layoutIfNeeded()
        })
        searchResults = []
        searchResultsTV.reloadData()
        self.showRemindersCVC()
    }
    
    func showRemindersCVC(){
        self.remindersCVC.collectionView.contentInset.top -= self.remindersCVC.collectionView.bounds.height
        self.remindersCVC.collectionView.scrollEnabled = true
        searchResultsTV.hidden = true
    }
    
    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        let itemText = searchResults[indexPath.row]["description"] as String
        return max(templateCell.cellHeightThatFitsForItemText(itemText),44)
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let itemCell:ReminderItemTableViewCell = self.searchResultsTV.dequeueReusableCellWithIdentifier("ReminderItemCell") as ReminderItemTableViewCell
        itemCell.initForSearchResults(searchResults[indexPath.row])
        return itemCell
    }
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        let selectedSearchResult = self.searchResults[indexPath.row]
        let cardIndex = selectedSearchResult["cardIndex"] as Int
        searchBar.text = ""
        searchBarCancelButtonClicked(searchBar)
        self.remindersCVC.exposeCard(NSIndexPath(forItem: cardIndex, inSection: 0))
    }
    
}
