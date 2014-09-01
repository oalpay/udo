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
    
    var state = 0
    
    override func viewWillAppear(animated: Bool) {
        loginButton.enabled = false
        askNumber()
    }
    
    func askNumber(){
        state = 0
        loginButton.enabled = false
        nameTextField.hidden = true
    }
    
    func askName(){
        state = 1
        loginButton.enabled = false
        nameTextField.hidden = false
        phoneNumberTextField.userInteractionEnabled = false
    }
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
    }
    
    @IBAction func registerPressed(AnyObject){
        var error:NSError?
        let userName = NBPhoneNumberUtil.sharedInstance().format(phoneNumber!, numberFormat: NBEPhoneNumberFormatE164, error: &error)
        if let e = error  {
            println("registerPressed:\(e.localizedDescription)")
            return
        }
        if state == 0{
            var query = PFUser.query()
            query.whereKey("username", equalTo: userName)
            query.countObjectsInBackgroundWithBlock({ (count:Int32, e: NSError!) -> Void in
                if e != nil{
                    println("registerPressed:\(e.localizedDescription)")
                    return
                }
                if count == 0{
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.askName()
                    })
                }else{
                    var error:NSError?
                    PFUser.logInWithUsername(userName, password: UIDevice.currentDevice().identifierForVendor.UUIDString, error: &error)
                    if let e = error{
                        println("logInWithUsername:\(e.localizedDescription)")
                    }else{
                        self.performSegueWithIdentifier("Login", sender: self)
                    }
                }

            })
        } else if state == 1 {
            var newUser = PFUser()
            newUser.username = userName
            newUser["name"] = nameTextField.text
            newUser.password = UIDevice.currentDevice().identifierForVendor.UUIDString
            newUser["country"] = phoneNumber!.countryCode
            newUser.signUpInBackgroundWithBlock {
                (succeeded: Bool!, error: NSError!) -> Void in
                if error == nil {
                    self.performSegueWithIdentifier("Login", sender: self)
                } else {
                    UIAlertView(title: "Error", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "Retry")
                    // Show the errorString somewhere and let the user try again.
                }
            }
        }
    }
    
    func textField(textField: UITextField!, shouldChangeCharactersInRange range: NSRange, replacementString string: String!) -> Bool {
        var phoneUtil:NBPhoneNumberUtil! = NBPhoneNumberUtil.sharedInstance()
        var shouldChange = true
        if state == 0{
            var error:NSError?
            var phoneNumberText = phoneNumberTextField.text as NSString
            var newString = "+" + phoneNumberText.stringByReplacingCharactersInRange(range, withString: string)
            phoneNumber = phoneUtil.parse(newString, defaultRegion: nil, error: &error)
            let formatedNumber = phoneUtil.format(phoneNumber, numberFormat: NBEPhoneNumberFormatINTERNATIONAL, error: &error)
            if error == nil{
                phoneNumberTextField.text = formatedNumber.substringFromIndex(formatedNumber.startIndex.successor())
                shouldChange = false
            }
            if phoneUtil.isValidNumber(phoneNumber){
                 loginButton.enabled = true
            }
        }else if state == 1 && nameTextField.text.isEmpty{
            loginButton.enabled = true
        }
        return shouldChange
    }

}