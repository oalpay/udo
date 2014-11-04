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
    @IBOutlet weak var profileImageView: PFImageView!
    @IBOutlet weak var profileImageEditButton: UIButton!
    
    let contactManager = ContactsManager.sharedInstance
    var me:UDContact!

    override func viewDidLoad() {
        self.me = self.contactManager.getUDContactForUserId(PFUser.currentUser().username)
        self.profileImageView.layer.cornerRadius = self.profileImageView.frame.size.height / 2
        self.profileImageView.layer.masksToBounds = true
        
        self.profileImageEditButton.addTarget(self, action: "editProfilePicturePressed:", forControlEvents: UIControlEvents.TouchUpInside)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.saveButton.enabled = false
        self.nameTextField.text = me.name()
        if let imageFile = me.userPublic?.image {
            self.profileImageView.file = me.userPublic?.image
            self.profileImageView.startAnimating()
            self.profileImageView.loadInBackground()
        }else{
            self.profileImageView.image = DefaultAvatarImage
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowProfileImageView" {
            let profileVC = segue.destinationViewController as ProfileImageViewController
            profileVC.udContact = self.me
        }
    }
    
    func editProfilePicturePressed(sender:AnyObject) {
        self.performSegueWithIdentifier("ShowProfileImageView", sender: nil)
    }
    
    @IBAction func saveButtonPressed(sender: AnyObject) {
        if let publicUser = me.userPublic {
            publicUser.name = self.nameTextField.text
            publicUser.saveEventually()
        }
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        var txtAfterUpdate:NSString = textField.text as NSString
        txtAfterUpdate = txtAfterUpdate.stringByReplacingCharactersInRange(range, withString: string)
        if let publicUser = me.userPublic {
            if txtAfterUpdate != publicUser.name && txtAfterUpdate != "" {
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
    @IBOutlet weak var profileImageView: PFImageView!
    
    let contactManager = ContactsManager.sharedInstance
    var udContact:UDContact!


    override func viewDidLoad() {
        if self.udContact.userId != PFUser.currentUser().username {
            self.navigationItem.rightBarButtonItem = nil
        }
        self.title = self.udContact.name()
        if let imageFile = self.udContact.userPublic?.image {
            self.profileImageView.file = imageFile
            self.profileImageView.startAnimating()
            self.profileImageView.loadInBackground()
        }else{
            self.profileImageView.image = DefaultAvatarImage
        }
    }

    @IBAction func editPressed(sender: AnyObject) {
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
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int){
        if actionSheet.buttonTitleAtIndex(buttonIndex) == "Delete" {
            self.udContact.userPublic?.image = nil
            self.udContact.userPublic?.saveEventually()
            self.profileImageView.image = DefaultAvatarImage
        }else if actionSheet.buttonTitleAtIndex(buttonIndex) == "Take new" {
            self.showUIImagePickerController(UIImagePickerControllerSourceType.Camera)
        }else if actionSheet.buttonTitleAtIndex(buttonIndex) == "Choose existing" {
            self.showUIImagePickerController(UIImagePickerControllerSourceType.PhotoLibrary)
        }
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
                let adjustedImage = chosenImage.resizedImageToFitInSize(CGSize(width: 640, height: 640), scaleIfSmaller: true)
                self.profileImageView.image = adjustedImage
                
                let imageData = UIImagePNGRepresentation(adjustedImage)
                let fileName = PFUser.currentUser().username.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "+"))
                let imageFile = PFFile(name: "profile_image_\(fileName)", data: imageData)
                self.udContact.userPublic?.image = imageFile
                self.udContact.userPublic?.saveInBackgroundWithBlock({ (_, error:NSError!) -> Void in
                    if error != nil {
                        println("Error saving image:" + error.localizedDescription)
                    }
                })
            }
        })
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController){
        picker.dismissViewControllerAnimated(true, completion: { () -> Void in
            
        })
    }

}