//
//  SettingsTableViewController.swift
//  udo
//
//  Created by Osman Alpay on 11/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import MessageUI

class SettingsTableViewController:UITableViewController,MFMessageComposeViewControllerDelegate{
    var contactsManager = ContactsManager.sharedInstance
    
    override func viewDidLoad() {
        self.navigationController?.navigationBar.titleTextAttributes =  [NSForegroundColorAttributeName: AppTheme.logoColor]
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 && indexPath.row == 1{
            self.sendInvitation()
        }
    }
    
    func sendInvitation(){
        if MFMessageComposeViewController.canSendText() {
            let recipents = []
            var messageController = MFMessageComposeViewController()
            messageController.messageComposeDelegate = self
            messageController.recipients = recipents
            messageController.body = self.contactsManager.getInvitationLetter()
            self.presentViewController(messageController, animated: true, completion: nil)
        }
    }
    
    
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        if result.value == MessageComposeResultFailed.value{
            UIAlertView(title: "Error", message: "Failed to send message", delegate: nil, cancelButtonTitle: "Continue").show()
        }else if result.value == MessageComposeResultSent.value {
            self.contactsManager.invitationSent(controller.recipients)
        }
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
}