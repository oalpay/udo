//
//  RegisterViewController.swift
//  udo
//
//  Created by Osman Alpay on 03/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import UIKit

class RegisterViewController: UIViewController,UITextFieldDelegate{
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField : UITextField!
    @IBOutlet weak var loginButton : UIButton!
    
    var phoneNumber:NBPhoneNumber?
    
    override func viewWillAppear(animated: Bool) {
        loginButton.enabled = false
    }
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
    }
    
    @IBAction func registerPressed(AnyObject){
        let user = PFUser()
        
        var error:NSError?
        let formatedNumberE164 = NBPhoneNumberUtil.sharedInstance().format(phoneNumber!, numberFormat: NBEPhoneNumberFormatE164, error: &error)
        if let e = error  {
            println("registerPressed:\(e.localizedDescription)")
            return
        }
        user.username = nameTextField.text
        user["number"] = formatedNumberE164
        user.password = UIDevice.currentDevice().identifierForVendor.UUIDString
        user["country"] = phoneNumber!.countryCode
        
        user.signUpInBackgroundWithBlock {
            (succeeded: Bool!, error: NSError!) -> Void in
            if error == nil {
                self.performSegueWithIdentifier("Login", sender: self)
            } else {
                UIAlertView(title: "Error", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "Retry")
                // Show the errorString somewhere and let the user try again.
            }
        }
    }
    
    func textField(textField: UITextField!, shouldChangeCharactersInRange range: NSRange, replacementString string: String!) -> Bool {
        var phoneUtil:NBPhoneNumberUtil! = NBPhoneNumberUtil.sharedInstance()
        var shouldChange = true
        if textField == phoneNumberTextField{
            var error:NSError?
            var phoneNumberText = phoneNumberTextField.text as NSString
            var newString = phoneNumberText.stringByReplacingCharactersInRange(range, withString: string)
            phoneNumber = phoneUtil.parse(newString, defaultRegion: nil, error: &error)
            let formatedNumber = phoneUtil.format(phoneNumber, numberFormat: NBEPhoneNumberFormatINTERNATIONAL, error: &error)
            if error == nil{
                phoneNumberTextField.text = formatedNumber
                shouldChange = false
            }
        }
        if phoneUtil.isValidNumber(phoneNumber) && !nameTextField.text.isEmpty {
            loginButton.enabled = true
        }
        return shouldChange
    }
    
}