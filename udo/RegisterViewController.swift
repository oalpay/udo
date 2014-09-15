//
//  RegisterViewController.swift
//  udo
//
//  Created by Osman Alpay on 03/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import UIKit


#if TARGET_IPHONE_SIMULATOR
var   devId = "QWER"
#else
var   devId = UIDevice.currentDevice().identifierForVendor.UUIDString
#endif

class RegisterViewController: UIViewController,UITextFieldDelegate{
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField : UITextField!
    @IBOutlet weak var loginButton : UIButton!
    @IBOutlet weak var passcodeTextField: UITextField!
    
    var nbPhoneNumber:NBPhoneNumber!
    var phoneNumber:String!
    var passcode:String!
    
    var state = 0
    
    override func viewDidLoad() {

    }
    
    override func viewWillAppear(animated: Bool) {
        loginButton.enabled = false
        askNumber()
    }
    
    func askNumber(){
        state = 0
        loginButton.enabled = false
        nameTextField.hidden = true
        self.passcodeTextField.hidden = true
        phoneNumberTextField.becomeFirstResponder()
    }
    
    func askNameAndPasscode(){
        state = 1
        self.createPassCodeAndSendSMS()
        loginButton.enabled = false
        nameTextField.hidden = false
        phoneNumberTextField.enabled = false
        nameTextField.becomeFirstResponder()
        self.passcodeTextField.hidden = false
    }
    
    func askPasscode(){
        state = 2
        loginButton.enabled = false
        nameTextField.hidden = false
        phoneNumberTextField.enabled = false
        nameTextField.becomeFirstResponder()
        self.passcodeTextField.hidden = false
    }
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
    }
    
    @IBAction func registerPressed(AnyObject){
        var error:NSError?
        self.phoneNumber = NBPhoneNumberUtil.sharedInstance().format(nbPhoneNumber, numberFormat: NBEPhoneNumberFormatE164, error: &error)
        if let e = error  {
            println("registerPressed:\(e.localizedDescription)")
            return
        }
        if state == 0{
            var query = PFUser.query()
            query.whereKey("username", equalTo: self.phoneNumber)
            query.countObjectsInBackgroundWithBlock({ (count:Int32, e: NSError!) -> Void in
                if e != nil{
                    println("registerPressed:\(e.localizedDescription)")
                    return
                }
                if count == 0{
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.askNameAndPasscode()
                    })
                }else{
                    var error:NSError?
                    PFUser.logInWithUsername(self.phoneNumber, password: devId, error: &error)
                    if let e = error{
                        println("logInWithUsername:\(e.localizedDescription)")
                    }else{
                        self.performSegueWithIdentifier("Loggedin", sender: self)
                    }
                }

            })
        } else if state == 1 {
            if self.passcodeTextField.text == self.passcode {
                self.view.userInteractionEnabled = false
                self.createUserAndGoBackToMain()
            }else {
                UIAlertView(title: "Error", message: "Passcode does not match", delegate: nil, cancelButtonTitle: "Okay").show()
            }
        }
    }
    
    func createUserAndGoBackToMain(){
        var newUser = PFUser()
        newUser.username = self.phoneNumber
        newUser["name"] = nameTextField.text
        newUser.password = UIDevice.currentDevice().identifierForVendor.UUIDString
        newUser["country"] = self.nbPhoneNumber.countryCode
        newUser.signUpInBackgroundWithBlock {
            (succeeded: Bool!, error: NSError!) -> Void in
            if error == nil {
                self.performSegueWithIdentifier("Loggedin", sender: self)
            } else {
                UIAlertView(title: "Error", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "Retry")
                // Show the errorString somewhere and let the user try again.
            }
        }

    }
    
    func createPassCodeAndSendSMS(){
        self.passcode = NSNumber(unsignedInt: arc4random() % 9000 + 1000).stringValue
        println(self.passcode)
        var params = Dictionary<String,String>()
        params["passcode"] = passcode
        params["number"] = self.phoneNumber
        PFCloud.callFunctionInBackground("sendSms", withParameters:params) {
            (result: AnyObject!, error: NSError!) -> Void in
            if error != nil {
                println("e:createPassCodeAndSendSMS:\(error.description)")
                UIAlertView(title: "Error", message: "Couldnt send the passcode, try again later", delegate: nil, cancelButtonTitle: "Okay").show()
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
            self.nbPhoneNumber = phoneUtil.parse(newString, defaultRegion: nil, error: &error)
            self.phoneNumber = phoneUtil.format(self.nbPhoneNumber, numberFormat: NBEPhoneNumberFormatINTERNATIONAL, error: &error)
            if error == nil{
                phoneNumberTextField.text =  self.phoneNumber.substringFromIndex( self.phoneNumber.startIndex.successor())
                shouldChange = false
            }
            if phoneUtil.isValidNumber(self.nbPhoneNumber){
                 loginButton.enabled = true
            }
        }else if state == 1 && nameTextField.text.isEmpty{
            loginButton.enabled = true
        }
        return shouldChange
    }

}