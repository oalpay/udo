//
//  ContactsHelper.swift
//  udo
//
//  Created by Osman Alpay on 28/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation
import AddressBookUI
import MessageUI

class  UDContact {
    init (userId:String!,imageCache:NSCache){
        self.userId = userId
        self.imageCache = imageCache
    }
    private let imageCache:NSCache!
    var userPublic:UserPublic?
    var userId:String!
    var apContact:APContact?
    private var thumbnail:UIImage!
    func name() -> String {
        if let up = userPublic {
            return up.name
        }else if let apc = apContact{
            if let apName = apc.compositeName {
                return apName
            }
        }
        return userId
    }
    func image() -> UIImage!{
        if let up = userPublic {
            if let imageFile = up.image {
                if let cachedImage = self.imageCache.objectForKey(self.userId) as? UIImage{
                    return cachedImage
                }else {
                    imageFile.getDataInBackgroundWithBlock({ (data:NSData!, error:NSError!) -> Void in
                        if error == nil {
                            if let profileImage = UIImage(data: data!) {
                                self.imageCache.setObject(profileImage, forKey: self.userId)
                            }
                        }
                    })
                }
            }
        }
        if thumbnail != nil {
            return thumbnail!
        }
        if let apImage = apContact?.thumbnail {
            return apImage
        }
        return DefaultAvatarImage
    }
    func hasImage() -> Bool {
        if self.thumbnail != nil {
            return true
        }
        if apContact?.thumbnail != nil {
            return true
        }
        return false
    }
}


var kContactsAccessGrantedNotification = "ContactsAccessGrantedNotification"
var kContactsAccessDenieddNotification = "ContactsAccessDenieddNotification"
var kContactsChangedNotification = "ContactsChangedNotification"

var DefaultAvatarImage = UIImage(named: "default-avatar")

class ContactsManager{
    class var sharedInstance : ContactsManager {
        struct Static {
            static let instance : ContactsManager = ContactsManager()
        }
        return Static.instance
    }
    private var imageCache = NSCache()
    private var registeredUserIds = NSDictionary()
    private var phoneUtil:NBPhoneNumberUtil! = NBPhoneNumberUtil.sharedInstance()
    private var addressBook = APAddressBook()
    
    var contacts:[APContact] = []
    private var userIdAPContactMap = NSDictionary()
    
    private var numberUserIdCache:NSDictionary!
    private var userDefaults = NSUserDefaults.standardUserDefaults()
    
    private var isListenerRegistered = false
    
    init() {
        var savedNumberUserIdMap =  userDefaults.dictionaryForKey("numberUserIdCache") as NSDictionary?
        if savedNumberUserIdMap == nil {
            self.numberUserIdCache = NSDictionary()
        }else {
            self.numberUserIdCache = savedNumberUserIdMap
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationWillEnterForegroundNotification:", name: UIApplicationWillEnterForegroundNotification, object: nil)
    }
    
    private func reset(){
        self.contacts.removeAll(keepCapacity: true)
        self.userIdAPContactMap = NSDictionary()
        self.addressBook.stopObserveChanges()
        self.isListenerRegistered = false
    }
    
    @objc func applicationWillEnterForegroundNotification(notification:NSNotification) {
        if !self.isAuthorized() {
            self.reset()
        }
    }
    
    
    func requestAccess( callback:(success:Bool,error:NSError!) -> Void ){
        self.addressBook.requestAccess { (success:Bool, error:NSError!) -> Void in
            dispatch_async(dispatch_get_main_queue(),{ () -> Void in
                callback(success: success, error: error)
            })
        }
    }
    
    func isAuthorized() -> Bool {
        if APAddressBook.access().rawValue == APAddressBookAccess.Granted.rawValue {
            return true
        }
        return false
    }
    
    private func syncPhoneNumberUserIdCache(){
        var mNumberUserIdCache = NSMutableDictionary()
        var mUserIdAPContactMap = NSMutableDictionary()
        for contact in self.contacts{
            for number in contact.phones as [String] {
                var userId = self.getUserIdFromPhoneNumber(number)
                mUserIdAPContactMap.setObject(contact, forKey: userId)
                mNumberUserIdCache.setObject(userId, forKey: number)
            }
        }
        self.userIdAPContactMap = NSDictionary(dictionary: mUserIdAPContactMap)
        
        self.numberUserIdCache = NSDictionary(dictionary: mNumberUserIdCache)
        self.userDefaults.setObject(self.numberUserIdCache, forKey: "numberUserIdCache")
    }
    
    
    private func loadContactsFromAddressBook( callback:(success:Bool,error:NSError!) -> Void) {
        self.addressBook.fieldsMask = APContactField.Default | APContactField.CompositeName | APContactField.Thumbnail
        self.addressBook.sortDescriptors = [NSSortDescriptor(key: "firstName", ascending: true),
            NSSortDescriptor(key: "lastName", ascending: true)]
        self.addressBook.filterBlock = {(contact: APContact!) -> Bool in
            return contact.phones.count > 0
        }
        self.addressBook.loadContactsOnQueue(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), completion: { (contacts: [AnyObject]!, error: NSError!) -> Void in
            if (contacts != nil) {
                self.contacts = contacts as [APContact]
                self.syncPhoneNumberUserIdCache()
            }
            var success = true
            if error != nil {
                success = false
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                callback(success: success, error: error)
            })
        })
    }
    
    func getUDContactsForAPcontact(apContact:APContact!) -> [UDContact]{
        var udContacts = [UDContact]()
        for phoneNumber in apContact.phones as [String]{
            if let udContact = self.getUDContactForPhoneNumber(phoneNumber) {
                udContacts.append(udContact)
            }
        }
        return udContacts
    }
    
    func getUDContactForPhoneNumber(number:String!) -> UDContact!{
        var userId =  self.getUserIdFromPhoneNumber(number)
        return self.getUDContactForUserId(userId)
    }
    
    func getUDContactForUserId(username:String!) -> UDContact!{
        var udContact = UDContact(userId: username,imageCache:self.imageCache)
        if let userPublic = self.registeredUserIds[username] as? UserPublic{
            udContact.userPublic = userPublic
        }
        if let apContact = self.userIdAPContactMap[username] as? APContact{
            udContact.apContact = apContact
        }
        return udContact
    }
    
    func isUserRegistered(userId:String!) -> Bool{
        if let user = self.registeredUserIds[userId] as? UserPublic{
            return true
        }else if self.userIdAPContactMap[userId] == nil {
            // not in our contact list, cant decide
            return true
        }
        return false
    }
    
    func loadContacts(contactsLoaded:(() -> Void)?){
        if self.isListenerRegistered {
            contactsLoaded?()
            return
        }
        self.loadContactsFromAddressBook{ (success:Bool, error:NSError!) -> Void in
            if success {
                self.addressBook.startObserveChangesWithCallback { () -> Void in
                    self.loadContactsFromAddressBook({ (success:Bool, error:NSError!) -> Void in
                        if success {
                            NSNotificationCenter.defaultCenter().postNotificationName(kContactsChangedNotification, object: nil)
                        }
                    })
                }
                self.isListenerRegistered = true
            }
            contactsLoaded?()
            return
        }
    }
    
    func refreshAppUsers(appUsersLoaded:(() -> Void)? ){
        self.getAppUsers({ () -> Void in
            appUsersLoaded?()
            return
        })
    }
    
    func getUserIdFromPhoneNumber(phoneNumber:String!) -> String! {
        var userId =  self.numberUserIdCache[phoneNumber] as? String
        if userId != nil {
            return userId!
        }
        let user = PFUser.currentUser()
        let userCountryCode = user["country"] as NSNumber
        let userRegionCode = phoneUtil.getRegionCodeForCountryCode(userCountryCode)
        var error:NSError?
        var nbPhoneNumber:NBPhoneNumber? = phoneUtil.parse(phoneNumber, defaultRegion: userRegionCode, error: &error)
        if error == nil {
            userId = phoneUtil.format(nbPhoneNumber, numberFormat: NBEPhoneNumberFormatE164, error: &error)
        }else{
            userId = phoneNumber
        }
        return userId!
    }
    
    private func getAppUsers( finished: (()-> Void)? ){
        var query = UserPublic.query()
        var myContactNumbers = NSMutableArray(array: self.numberUserIdCache.allValues)
        myContactNumbers.addObject(PFUser.currentUser().username) // add myself
        myContactNumbers.addObject("0") // add udo
        query.whereKey("username", containedIn: myContactNumbers)
        //query.cachePolicy = kPFCachePolicyCacheThenNetwork
        query.findObjectsInBackgroundWithBlock { (users:[AnyObject]!, error:NSError!) -> Void in
            if error != nil {
                println("e:getAppUsers:\(error.localizedDescription)")
                return
            }
            var registeredUsers = NSMutableDictionary()
            for user in users as [UserPublic] {
                registeredUsers.setValue(user, forKey: user.username)
            }
            self.registeredUserIds = registeredUsers.copy() as NSDictionary
            finished?()
        }
    }
    
    func getInvitationLetter() -> String {
        var config = PFConfig.currentConfig()
        if config != nil {
            return config["invitationSMS"] as String
        }else {
            return ""
        }
    }
    
    func invitationSent(recipients:[AnyObject]){
        var invitation = PFObject(className: "Invitation")
        invitation["to"] = recipients
        invitation["from"] = PFUser.currentUser().username
        invitation.saveEventually()
    }
    
}
