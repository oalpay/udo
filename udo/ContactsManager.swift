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

class ContactNumber{
    var contact:Contact!
    var original:String!
    var userId:String!
    init(){
        
    }
    
    func toDictionary() -> NSDictionary! {
        var dic = NSMutableDictionary()
        dic.setObject(original, forKey: "original")
        dic.setObject(userId, forKey: "userId")
        return dic
    }
    
    class func fromDictionary(dic:NSDictionary!,contact:Contact) -> ContactNumber{
        var number = ContactNumber()
        number.contact = contact
        number.original = dic.objectForKey("original") as String?
        number.userId = dic.objectForKey("userId") as String?
        return number
    }
}

class Contact{
    var image:UIImage?
    var name:String?
    var tokens:[String]!
    var numbers:[ContactNumber] = []
    init(){
        
    }
    
    func toDictionary() -> NSDictionary! {
        var dic = NSMutableDictionary()
        dic.setObject(name!, forKey: "name")
        var numbersDic = [NSDictionary]()
        for number in self.numbers {
            numbersDic.append(number.toDictionary())
        }
        dic.setObject(numbersDic, forKey: "numbers")
        return dic
    }
    
    class func fromDictionary(dic:NSDictionary!) -> Contact{
        var contact = Contact()
        contact.name = dic.objectForKey("name") as String?
        contact.numbers = [ContactNumber]()
        for numberDic in dic.objectForKey("numbers") as [NSDictionary]{
             contact.numbers.append(ContactNumber.fromDictionary(numberDic, contact: contact))
        }
        return contact
    }
}

var kContactsAccessGrantedNotification = "ContactsAccessGrantedNotification"
var kContactsAccessDenieddNotification = "ContactsAccessDenieddNotification"
var kContactsChangedNotification = "ContactsChanged"

class ContactsManager{
    class var sharedInstance : ContactsManager {
    struct Static {
        static let instance : ContactsManager = ContactsManager()
        }
        return Static.instance
    }
    
    var registeredNumbers:Dictionary<String,String>!
    var phoneUtil:NBPhoneNumberUtil! = NBPhoneNumberUtil.sharedInstance()
    var addressBook: ABAddressBookRef?
    
    var contacts:[Contact] = []
    var contactsMap = Dictionary<String,ContactNumber>()
    
    var numberUserIdMap:Dictionary<String,String>!
    var userDefaults = NSUserDefaults.standardUserDefaults()
    
    init() {
        var errorRef: Unmanaged<CFError>? = nil
        self.addressBook = ABAddressBookCreateWithOptions(nil, &errorRef).takeRetainedValue()
        self.registeredNumbers = userDefaults.dictionaryForKey("registeredNumbers") as Dictionary<String,String>?
        if self.registeredNumbers == nil {
            self.registeredNumbers = Dictionary<String,String>()
        }
        var savedNumberUserIdMap =  userDefaults.dictionaryForKey("numberUserIdMap") as Dictionary<String,String>?
        if savedNumberUserIdMap == nil {
            self.numberUserIdMap = Dictionary<String,String>()
        }else {
            self.numberUserIdMap = savedNumberUserIdMap
        }
    }

    
    func isAuthorized() -> Bool {
        return ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Authorized
    }
    
    func authorize( success:()->Void, error:()->Void ){
        if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.NotDetermined) {
            var errorRef: Unmanaged<CFError>? = nil
            ABAddressBookRequestAccessWithCompletion(addressBook, { s, e in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if s {
                        success()
                    }
                    else {
                        println("e:ContactsHelper:authorize: \(e)")
                        error()
                    }
                })
            })
        }
        else if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Denied || ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Restricted) {
            error()
        }
        else if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Authorized) {
            success()
        }
        
    }
    
    private func reloadContacts(){
        var newContacts = [Contact]()
        var newContactsMap = Dictionary<String,ContactNumber>()
        var errorRef: Unmanaged<CFError>?
        var contactList: NSArray = ABAddressBookCopyArrayOfAllPeople(addressBook).takeRetainedValue()
        for record:ABRecordRef in contactList {
            var contact = Contact()
            contact.image = imageForContact(record)
            var name = ABRecordCopyCompositeName(record).takeRetainedValue() as NSString?
            if name == nil {
                contact.name = ""
            }else{
                contact.name = name
                var tokens = [String]()
                for token in name!.componentsSeparatedByString(" "){
                    tokens.append(token.lowercaseString)
                }
                contact.tokens = tokens
            }
            
            let uPhoneNumbers = ABRecordCopyValue(record, kABPersonPhoneProperty)
            let phones: ABMultiValueRef =
            Unmanaged<NSObject>.fromOpaque(uPhoneNumbers.toOpaque()).takeUnretainedValue() as ABMultiValueRef
            for (var i = 0; i < ABMultiValueGetCount(phones); ++i)
            {
                var uPhoneNumber = ABMultiValueCopyValueAtIndex(phones, i)
                let phoneNumber: String = Unmanaged<NSObject>.fromOpaque(
                    uPhoneNumber.toOpaque()).takeUnretainedValue() as String
                var contactNumber = ContactNumber()
                contactNumber.original = phoneNumber
                contactNumber.userId = convertPhoneNumberToUserId(phoneNumber)
                contactNumber.contact = contact
                contact.numbers.append(contactNumber)
                newContactsMap[contactNumber.userId] = contactNumber
            }
            if contact.numbers.count > 0 {
                newContacts.append(contact)
            }
        }
        newContacts.sort({ (c1:Contact, c2:Contact) -> Bool in
            return c1.name < c2.name
        })
        self.contacts = newContacts
        self.contactsMap = newContactsMap
        userDefaults.setObject(self.numberUserIdMap, forKey: "numberUserIdMap")
        userDefaults.synchronize()
    }
    
    func imageForContact(recordRed:ABRecordRef) -> UIImage?{
        if (ABPersonHasImageData(recordRed)) {
            var imgData:CFData = ABPersonCopyImageDataWithFormat(recordRed, kABPersonImageFormatThumbnail).takeRetainedValue()
            return UIImage(data: imgData)
        }
        return nil
    }
    
    
    func convertPhoneNumberToUserId(phoneNumber:String!) -> String {
        var userId =  self.numberUserIdMap[phoneNumber]
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
        self.numberUserIdMap[phoneNumber] = userId
        return userId!
    }
    
    
    func getContactNumberForUserId(userId:String!) -> ContactNumber{
        if userId == PFUser.currentUser().username {
            var me = Contact()
            me.name = PFUser.currentUser()["name"] as? String
            var number = ContactNumber()
            number.contact = me
            number.userId = userId
            return number
        }
        var number = self.contactsMap[userId]
        if number != nil {
            return number!
        }
        var unknownContact = Contact()
        if userId == "0" {
            unknownContact.name = "u.do"
            unknownContact.image = UIImage(named: "udoAvatar")
        }
        var unknownNumber = ContactNumber()
        unknownNumber.contact = unknownContact
        unknownNumber.userId = userId
        unknownNumber.original = userId
        return unknownNumber
    }
    
    func isNumberRegistered(number:ContactNumber) -> Bool{
        var user = self.registeredNumbers[number.userId]
        if user == nil{
            return false
        }
        return true
    }
    
    func refreshContactsAndAppUsers(contactsLoaded:(() -> Void)? ,appUsersLoaded:(() -> Void)? ){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),{ () -> Void in
            self.reloadContacts()
            dispatch_async(dispatch_get_main_queue(),{ () -> Void in
                contactsLoaded?()
                return
            })
            self.getAppUsers({ () -> Void in
                dispatch_async(dispatch_get_main_queue(),{ () -> Void in
                    appUsersLoaded?()
                    return
                })
            })
        })
    }
    
    private func getAppUsers( finished: (()-> Void)? ){
        var numbers:[String] = []
        for contact in self.contacts{
            for number in contact.numbers{
                if let userId = number.userId{
                    numbers.append(userId)
                }
            }
        }
        var params = Dictionary<String,AnyObject>()
        params["numbers"] = numbers
        PFCloud.callFunctionInBackground("appUsers", withParameters:params) {
            (result: AnyObject!, error: NSError!) -> Void in
            if error == nil {
                for user in result as [String] {
                    self.registeredNumbers[user] = ""
                }
                self.userDefaults.setObject(self.registeredNumbers, forKey: "registeredNumbers")
                self.userDefaults.synchronize()
            }
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
