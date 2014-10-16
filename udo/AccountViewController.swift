//
//  AccountViewController.swift
//  udo
//
//  Created by Osman Alpay on 04/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class AccountViewController:UITableViewController, UITextFieldDelegate{
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var nameTextField: UITextField!
    
    override func viewWillAppear(animated: Bool) {
        self.saveButton.enabled = false
        var user = PFUser.currentUser()
        self.nameTextField.text = user["name"] as String
    }
    
    @IBAction func saveButtonPressed(sender: AnyObject) {
        var user = PFUser.currentUser()
        user["name"] = self.nameTextField.text
        user.saveEventually()
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        var txtAfterUpdate:NSString = textField.text as NSString
        txtAfterUpdate = txtAfterUpdate.stringByReplacingCharactersInRange(range, withString: string)
        let name = PFUser.currentUser()["name"] as String
        if txtAfterUpdate != name && txtAfterUpdate != "" {
             self.saveButton.enabled = true
        }else{
            self.saveButton.enabled = false
        }

        return true
    }
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 1 {
            PFUser.logOut()
            NSNotificationCenter.defaultCenter().postNotificationName(kUserLoggedOutNotification, object: nil)
            self.performSegueWithIdentifier("Logout", sender: nil)
        }
    }
}