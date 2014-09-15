//
//  AccountViewController.swift
//  udo
//
//  Created by Osman Alpay on 04/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class AccountViewController:UITableViewController{
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        PFUser.logOut()
        self.performSegueWithIdentifier("Logout", sender: nil)
    }
}