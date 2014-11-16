//
//  SettingsTableViewController.swift
//  udo
//
//  Created by Osman Alpay on 11/10/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import MessageUI

class SettingsTableViewController:UITableViewController,MFMessageComposeViewControllerDelegate,MFMailComposeViewControllerDelegate{
    var contactsManager = ContactsManager.sharedInstance
    
    override func viewDidLoad() {
        self.navigationController?.navigationBar.titleTextAttributes =  [NSForegroundColorAttributeName: AppTheme.logoColor]
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 1 && indexPath.row == 1{
            self.sendInvitation()
        }else if indexPath.section == 1 && indexPath.row == 2{
            self.sendFeedback()
        }else if indexPath.section == 2 && indexPath.row == 0{
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: kSkipTutorial)
            self.performSegueWithIdentifier("BackFromSettings", sender: nil)
        }
        self.tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }
    
    func sendFeedback(){
        if MFMailComposeViewController.canSendMail() {
            let emailTitle = "Hi"
            let messageBody = ""
            let toRecipents = ["support@udoapp.info"]
            
            let mc = MFMailComposeViewController()
            mc.mailComposeDelegate = self
            mc.setSubject(emailTitle)
            mc.setMessageBody(messageBody, isHTML: false)
            mc.setToRecipients(toRecipents)
            self.presentViewController(mc, animated: true, completion: nil)
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
              TSMessage.showNotificationWithTitle("Error", subtitle: "Failed to send message", type: TSMessageNotificationType.Error)
        }else if result.value == MessageComposeResultSent.value {
            self.contactsManager.invitationSent(controller.recipients)
        }
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        if result.value == MFMailComposeResultSent.value {
            UIAlertView(title: nil, message: "Thank you for sharing your thoughts with us", delegate: nil, cancelButtonTitle: "Ok").show()
        }
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
}