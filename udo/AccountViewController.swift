//
//  AccountViewController.swift
//  udo
//
//  Created by Osman Alpay on 04/09/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

private var isSavingMe = false
private var isFailedToSave = false

class AccountViewController:UITableViewController, UITextFieldDelegate{
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var profileImageView: UDContactImageView!
    @IBOutlet weak var profileImageEditButton: UIButton!
    
    let nc = NSNotificationCenter.defaultCenter()
    var imageLoadingActivityIndicator:UIActivityIndicatorView!
    var savingMeActivityIndicator:UIActivityIndicatorView!
    
    let contactManager = ContactsManager.sharedInstance
    var me:UDContact!
    
    override func viewDidLoad() {
        self.profileImageView.layer.cornerRadius = self.profileImageView.frame.size.height / 2
        self.profileImageView.layer.masksToBounds = true
        
        self.savingMeActivityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        
        self.profileImageEditButton.addTarget(self, action: "editProfilePicturePressed:", forControlEvents: UIControlEvents.TouchUpInside)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.me = self.contactManager.getUDContactForUserId(PFUser.currentUser().username)
        self.showProfile()
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.nc.removeObserver(self)
    }
    
    func showProfile(){
        self.nameTextField.text = me.name()
        self.profileImageView.loadWithContact(me, showIndicator: true)
        if let imageFile = self.me.userPublic {
            if isSavingMe {
                self.showActivity()
            }
        }else {
            //profile is not loaded yet
            self.showActivity()
            self.nc.addObserver(self, selector: "appUsersRefreshed:", name: kAppUsersRefreshedNotification, object: nil)
        }
        if isFailedToSave {
            self.saveButton.enabled = true
            self.saveButton.title = "Save!"
        }else {
            self.saveButton.enabled = false
            self.saveButton.title = "Save"
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowProfileImageView" {
            let profileVC = segue.destinationViewController as ProfileImageViewController
            profileVC.udContact = self.me
        }
    }
    
    func appUsersRefreshed(notification:NSNotification){
        self.me = self.contactManager.getUDContactForUserId(PFUser.currentUser().username)
        self.showProfile()
        self.hideActivity()
    }
    
    func showActivity(){
        self.savingMeActivityIndicator.startAnimating()
        self.navigationItem.titleView = self.savingMeActivityIndicator
        self.profileImageEditButton.enabled = false
        self.saveButton.enabled = false
        self.nameTextField.enabled = false
    }
    
    func hideActivity(){
        self.savingMeActivityIndicator.stopAnimating()
        self.navigationItem.titleView = nil
        self.profileImageEditButton.enabled = true
        self.saveButton.enabled = true
        self.nameTextField.enabled = true
    }
    
    func editProfilePicturePressed(sender:AnyObject) {
        self.performSegueWithIdentifier("ShowProfileImageView", sender: nil)
    }
    
    @IBAction func unwind(segue:UIStoryboardSegue){
        if segue.identifier == "SaveImage" {
            let pVC = segue.sourceViewController as ProfileImageViewController
            self.saveImage(pVC.selectedImage)
        }
    }
    
    func saveImage(image:UIImage!){
        self.me.cachePublicImage(image)
        if let userPublic = self.me.userPublic {
            if let i = image {
                self.showActivity()
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                    let adjustedImage = i.resizedImageToFitInSize(CGSize(width: 640, height: 640), scaleIfSmaller: false)
                    let imageData = UIImageJPEGRepresentation(adjustedImage, 0.5)
                    let fileName = self.me.userId.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "+"))
                    let imageFile = PFFile(name: "profile_image_\(fileName)", data: imageData)
                    userPublic.image = imageFile
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.saveMe()
                    })
                })
               
            }else {
                userPublic.image = nil
                self.saveMe()
            }
        }
    }
    
    func saveMe(){
        if let userPublic = self.me.userPublic {
            isSavingMe = true
            self.showActivity()
            userPublic.saveInBackgroundWithBlock({ (_, error:NSError!) -> Void in
                if error != nil {
                    isFailedToSave = true
                    UIAlertView(title: "Error", message: "Couldnt save your profile", delegate: nil, cancelButtonTitle: "Cancel").show()
                }else {
                    isFailedToSave = false
                }
                isSavingMe = false
                self.hideActivity()
                self.showProfile()
            })
        }
    }

    
    @IBAction func saveButtonPressed(sender: AnyObject) {
        if let publicUser = me.userPublic {
            publicUser.name = self.nameTextField.text
            self.saveMe()
        }
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        var txtAfterUpdate:NSString = textField.text as NSString
        txtAfterUpdate = txtAfterUpdate.stringByReplacingCharactersInRange(range, withString: string)
        if let publicUser = me.userPublic {
            if (txtAfterUpdate != publicUser.name && txtAfterUpdate != "") || isFailedToSave {
                self.saveButton.enabled = true
            }else{
                self.saveButton.enabled = false
            }
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

class ProfileImageViewController:UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate{
    @IBOutlet weak var profileImageView: UDContactImageView!
    
    let contactManager = ContactsManager.sharedInstance
    var udContact:UDContact!
    var selectedImage:UIImage!
    var isSaveState = false
    
    override func viewDidLoad() {
        if self.udContact.userId != PFUser.currentUser().username {
            self.navigationItem.rightBarButtonItem = nil
        }
        self.title = self.udContact.name()
        self.showUserImage()
    }
    
    func showUserImage(){
        profileImageView.loadWithContact(udContact, showIndicator: true)
    }
    
    @IBAction func editPressed(sender: AnyObject) {
        if isSaveState {
            self.performSegueWithIdentifier("SaveImage", sender: nil)
        }else {
            var actionSheet = UIActionSheet()
            actionSheet.delegate = self
            if self.udContact.userPublic?.image != nil {
                let delete = actionSheet.addButtonWithTitle("Delete")
                actionSheet.destructiveButtonIndex = delete
            }
            if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera){
                actionSheet.addButtonWithTitle("Take new")
            }
            if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.PhotoLibrary){
                actionSheet.addButtonWithTitle("Choose existing")
            }
            let cancel = actionSheet.addButtonWithTitle("Cancel")
            actionSheet.cancelButtonIndex = cancel
            actionSheet.showInView(self.view)
        }
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int){
        if actionSheet.buttonTitleAtIndex(buttonIndex) == "Delete" {
            self.selectedImage = nil
            self.profileImageView.image = DefaultAvatarImage
            self.goToSaveState()
        }else if actionSheet.buttonTitleAtIndex(buttonIndex) == "Take new" {
            self.showUIImagePickerController(UIImagePickerControllerSourceType.Camera)
        }else if actionSheet.buttonTitleAtIndex(buttonIndex) == "Choose existing" {
            self.showUIImagePickerController(UIImagePickerControllerSourceType.PhotoLibrary)
        }
    }
    
    func goToSaveState(){
        self.isSaveState = true
        self.navigationItem.rightBarButtonItem?.title = "Save"
        let cancelButton = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.Bordered, target: self, action: "cancelPressed:")
        self.navigationItem.leftBarButtonItem = cancelButton
    }
    
    func cancelPressed(sender:AnyObject){
        self.navigationItem.leftBarButtonItem = nil
        self.navigationItem.rightBarButtonItem?.title = "Edit"
        self.isSaveState = false
        self.showUserImage()
    }
    
    
    func showUIImagePickerController( sourceType:UIImagePickerControllerSourceType){
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = sourceType
        self.presentViewController(picker, animated: true) { () -> Void in
            
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]){
        picker.dismissViewControllerAnimated(true, completion: { () -> Void in
            if let chosenImage = info[UIImagePickerControllerEditedImage] as? UIImage {
                self.profileImageView.image = chosenImage
                self.selectedImage = chosenImage
                self.goToSaveState()
            }
        })
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController){
        picker.dismissViewControllerAnimated(true, completion: { () -> Void in
            
        })
    }
    
}