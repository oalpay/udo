//
//  RegisterViewController.swift
//  udo
//
//  Created by Osman Alpay on 03/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import UIKit

typealias ActionCall = ( button:ActionButton ) -> Void

class ActionButton:UIButton{
    var activityIndicator:UIActivityIndicatorView!
    var action:ActionCall?
    var oldEnabledState:Bool!
    var textField:UITextField!
    
    override func awakeFromNib() {
        self.activityIndicator = UIActivityIndicatorView(frame: CGRect(x: self.bounds.width - 30, y: 2.5 , width: 25, height: 25))
        self.activityIndicator.hidesWhenStopped = true
        self.addSubview(self.activityIndicator)
        
        self.addTarget(self, action: "callAction:", forControlEvents: UIControlEvents.TouchUpInside)
        
        self.setBackgroundImage(disabledBackgroundImage(), forState: UIControlState.Disabled)
    }
    
    
    func disabledBackgroundImage() -> UIImage {
        var rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        var context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, UIColor.lightGrayColor().CGColor);
        CGContextFillRect(context, rect);
        var image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image
    }
    
    
    func setAction(action:ActionCall!,withTitle title:String, textField: UITextField) {
        self.setTitle(title, forState: UIControlState.Normal)
        self.setTitle(title, forState: UIControlState.Highlighted)
        self.setTitle(title, forState: UIControlState.Disabled)
        self.action = action
        self.textField = textField
    }
    
    func callAction(sender:AnyObject){
        self.textField.resignFirstResponder()
        if let action = self.action{
            action( button:self )
        }
    }
    
    func showActivity(){
        self.oldEnabledState = self.enabled
        self.enabled = false
        self.activityIndicator.startAnimating()
    }
    func hideActivity(){
        self.enabled = self.oldEnabledState
        self.activityIndicator.stopAnimating()
    }
}


class RegisterViewController: UIViewController,UITextFieldDelegate{
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField : UITextField!
    @IBOutlet weak var loginButton : ActionButton!
    @IBOutlet weak var passcodeTextField: UITextField!
    @IBOutlet weak var cancelButton: ActionButton!
    
    var phoneUtil = NBPhoneNumberUtil.sharedInstance()
    var nbPhoneNumber:NBPhoneNumber!
    var username:String!
    var passcode:String!
    var loginAction:ActionCall!
    
    override func viewDidLoad() {
        self.cancelButton.setAction(askNumber, withTitle: "Cancel",textField: self.phoneNumberTextField)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.askNumber( self.loginButton )
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func devId() -> String {
        if UIDevice.currentDevice().model == "iPhone Simulator" {
            return "QWER"
        }else{
            return UIDevice.currentDevice().identifierForVendor.UUIDString
        }
    }
    
    func askNumber( button:ActionButton ){
        self.phoneNumberTextField.text = ""
        self.phoneNumberTextField.enabled = true
        self.phoneNumberTextField.becomeFirstResponder()
        self.cancelButton.hidden = true
        self.loginButton.enabled = false
        self.nameTextField.text = ""
        self.nameTextField.hidden = true
        self.passcodeTextField.hidden = true
        self.passcodeTextField.text = ""
        self.loginButton.setAction(queryUser, withTitle: "Login",textField: self.phoneNumberTextField)
    }
    
    func askName(){
        self.cancelButton.hidden = false
        self.nameTextField.hidden = false
        self.nameTextField.enabled = true
        self.nameTextField.becomeFirstResponder()
        self.phoneNumberTextField.enabled = false
        self.loginButton.enabled = false
        self.loginAction = self.createUserAndGoBackToMain
        self.loginButton.setAction( self.createAndSendPasscode , withTitle: "Send SMS Code",textField: self.nameTextField)
    }
    
    func askPasscode(){
        self.nameTextField.enabled = false
        self.passcodeTextField.hidden = false
        self.passcodeTextField.becomeFirstResponder()
    }
    
    func askResetPasswordForUser( username:String ){
        self.nameTextField.hidden = true
        self.nameTextField.text = username
        self.phoneNumberTextField.enabled = false
        self.loginButton.enabled = true
        self.cancelButton.hidden = false
        self.loginAction = self.resetPassword
        self.loginButton.setAction(self.createAndSendPasscode, withTitle: "Send SMS Code",textField: self.phoneNumberTextField)
    }
    
    func resetPassword( button:ActionButton ) {
        button.showActivity()
        var params = Dictionary<String,String>()
        params["username"] = self.username
        params["passcode"] = self.passcodeTextField.text
        params["password"] = self.devId()
        PFCloud.callFunctionInBackground("resetPassword", withParameters:params) {
            (result: AnyObject!, error: NSError!) -> Void in
            if error != nil {
                button.hideActivity()
                println("e:resetPassword:\(error.description)")
                UIAlertView(title: "Error", message: error.userInfo?.description , delegate: nil, cancelButtonTitle: "Ok").show()
            }else{
                PFUser.logInWithUsernameInBackground(self.username, password: self.devId(), block: { (_, error:NSError!) -> Void in
                    button.hideActivity()
                    if error != nil {
                        println("e:resetPassword:\(error.description)")
                        UIAlertView(title: "Error", message: error.userInfo?.description , delegate: nil, cancelButtonTitle: "Ok").show()
                    }else{
                        self.performSegueWithIdentifier("Loggedin", sender: self)
                    }
                })
            }
        }
    }
    
    func createAndSendPasscode( button:ActionButton ) {
        button.showActivity()
        var params = Dictionary<String,String>()
        params["username"] = self.username
        PFCloud.callFunctionInBackground("createAndSendPasscode", withParameters:params) {
            (result: AnyObject!, error: NSError!) -> Void in
            button.hideActivity()
            if error != nil {
                println("e:setPasscodeWithSuccess:\(error.description)")
                UIAlertView(title: "Error", message: error.userInfo?.description , delegate: nil, cancelButtonTitle: "Ok").show()
            }else{
                self.askPasscode()
                self.loginButton.setAction(self.createAndSendPasscode, withTitle: "Resend SMS Code",textField: self.phoneNumberTextField)
            }
        }
    }
    
    func queryUser( button:ActionButton ){
        button.showActivity()
        var query = PFUser.query()
        query.whereKey("username", equalTo: self.username)
        query.getFirstObjectInBackgroundWithBlock({ (userObject:PFObject!, error: NSError!) -> Void in
            button.hideActivity()
            if error != nil && error.code != kPFErrorObjectNotFound{
                println("e:queryUser:\(error.description)")
                UIAlertView(title: "Error", message: error.userInfo?.description , delegate: nil, cancelButtonTitle: "Ok").show()
            }else if userObject == nil {
                //new user
                self.askName()
            }else{
                //existing user
                let user = userObject as PFUser
                PFUser.logInWithUsernameInBackground(user.username, password: self.devId(), block: { (_, error:NSError!) -> Void in
                    if error != nil {
                        if error.code == kPFErrorObjectNotFound {
                            self.askResetPasswordForUser(user.username)
                        }else{
                            println("e:queryUser:\(error.description)")
                            UIAlertView(title: "Error", message: error.userInfo?.description , delegate: nil, cancelButtonTitle: "Ok").show()
                        }
                    }else{
                        self.userLoggedIn()
                    }
                })
            }
            
        })
    }
    
    @IBAction func unwindToMain(unwindSegue:UIStoryboardSegue){
        
    }
    
    func createUserAndGoBackToMain( button:ActionButton ){
        button.showActivity()
        var params = Dictionary<String,AnyObject>()
        params["username"] = self.username
        params["password"] = self.devId()
        params["country"] = self.nbPhoneNumber.countryCode
        params["name"] = self.nameTextField.text
        params["passcode"] = self.passcodeTextField.text
        PFCloud.callFunctionInBackground("signUpUser", withParameters:params) {
            (result: AnyObject!, error: NSError!) -> Void in
            if error != nil {
                button.hideActivity()
                println("createUserAndGoBackToMain:\(error.userInfo?.description)")
                UIAlertView(title: "Error", message: error.userInfo?.description , delegate: nil, cancelButtonTitle: "Ok").show()
            }else{
                PFUser.becomeInBackground(result["sessionToken"] as String , block: { (_, error:NSError!) -> Void in
                    button.hideActivity()
                    if error != nil {
                        println("createUserAndGoBackToMain:\(error.userInfo?.description)")
                        UIAlertView(title: "Error", message: error.userInfo?.description , delegate: nil, cancelButtonTitle: "Ok").show()
                    }else{
                       self.userLoggedIn()
                    }
                })
            }
        }
    }
    
    func userLoggedIn(){
        NSNotificationCenter.defaultCenter().postNotificationName(kUserLoggedInNotification, object: nil)
        self.performSegueWithIdentifier("Loggedin", sender: self)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.loginButton.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
        return true
    }
    
    
    func textField(textField: UITextField!, shouldChangeCharactersInRange range: NSRange, replacementString string: String!) -> Bool {
        loginButton.enabled = false
        var newText = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        if textField == self.phoneNumberTextField{
            var shouldChange = true
            var error:NSError?
            self.nbPhoneNumber = phoneUtil.parse("+" + newText, defaultRegion: nil, error: &error)
            let prettyPhoneNumber = phoneUtil.format(self.nbPhoneNumber, numberFormat: NBEPhoneNumberFormatINTERNATIONAL, error: &error)
            if error == nil{
                self.username = phoneUtil.format(self.nbPhoneNumber, numberFormat: NBEPhoneNumberFormatE164, error: &error)
                if error == nil {
                    phoneNumberTextField.text =  prettyPhoneNumber.substringFromIndex( prettyPhoneNumber.startIndex.successor())
                    shouldChange = false
                }
            }
            if phoneUtil.isValidNumber(self.nbPhoneNumber){
                loginButton.enabled = true
            }
            return shouldChange
        }else if textField == self.nameTextField{
            if !newText.isEmpty{
                loginButton.enabled = true
            }
        }else if textField == self.passcodeTextField {
            if countElements(newText) > 0 {
                self.loginButton.setAction(self.loginAction, withTitle: "Login",textField: self.passcodeTextField)
            } else {
                self.loginButton.setAction(self.createAndSendPasscode, withTitle: "Resend SMS Code",textField: self.phoneNumberTextField)
            }
            loginButton.enabled = true
        }
        return true
    }
    
}