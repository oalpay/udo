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
}

class Contact{
    var image:UIImage?
    var name:String!
    var numbers:[ContactNumber] = []
    init(){
        
    }
}

class ContactsHelper{
    class var sharedInstance : ContactsHelper {
    struct Static {
        static let instance : ContactsHelper = ContactsHelper()
        }
        return Static.instance
    }
    
    var registeredNumbers:NSSet!
    var phoneUtil:NBPhoneNumberUtil! = NBPhoneNumberUtil.sharedInstance()
    var addressBook: ABAddressBookRef?
    var contacts:[Contact]!
    var isAuthorized = false
    
    init() {
        var errorRef: Unmanaged<CFError>? = nil
        addressBook = ABAddressBookCreateWithOptions(nil, &errorRef).takeRetainedValue()
    }
    
    func authorize( success:()->Void, fail: ()->Void){
        if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.NotDetermined) {
            var errorRef: Unmanaged<CFError>? = nil
            ABAddressBookRequestAccessWithCompletion(addressBook, { s, e in
                if s {
                    self.isAuthorized = true
                    self.getContacts()
                    success()
                }
                else {
                    println("ContactsViewController: \(e)")
                    fail()
                }
            })
        }
        else if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Denied || ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Restricted) {
            fail()
        }
        else if (ABAddressBookGetAuthorizationStatus() == ABAuthorizationStatus.Authorized) {
            self.isAuthorized = true
            self.getContacts()
            success()
        }
        
    }
    
    func getContacts(){
        self.contacts = []
        var errorRef: Unmanaged<CFError>?
        var contactList: NSArray = ABAddressBookCopyArrayOfAllPeople(addressBook).takeRetainedValue()
        for record:ABRecordRef in contactList {
            var contact = Contact()
            contact.image = imageForContact(record)
            let name:Unmanaged<CFString>? = ABRecordCopyCompositeName(record)
            if let name = name?.takeRetainedValue() as NSString?{
                contact.name = name
            }else{
                contact.name = ""
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
            }
            if contact.numbers.count > 0 {
                contacts.append(contact)
            }
        }
    }
    func imageForContact(recordRed:ABRecordRef) -> UIImage?{
        if (ABPersonHasImageData(recordRed)) {
            var imgData:CFData = ABPersonCopyImageDataWithFormat(recordRed, kABPersonImageFormatThumbnail).takeRetainedValue()
            return UIImage(data: imgData)
        }
        return nil
    }
    
    
    func convertPhoneNumberToUserId(phoneNumber:String) -> String? {
        let user = PFUser.currentUser()
        let userCountryCode = user["country"] as NSNumber
        let userRegionCode = phoneUtil.getRegionCodeForCountryCode(userCountryCode)
        var error:NSError?
        let nbPhoneNumber:NBPhoneNumber = phoneUtil.parse(phoneNumber, defaultRegion: userRegionCode, error: &error)
        if error == nil {
            return phoneUtil.format(nbPhoneNumber, numberFormat: NBEPhoneNumberFormatE164, error: &error)
        }
        return nil
    }
    
    
    func getContactNumberForUserId(userId:String!) -> ContactNumber{
        if userId == PFUser.currentUser().username {
            var me = Contact()
            me.name = PFUser.currentUser()["name"] as String
            var number = ContactNumber()
            number.contact = me
            number.userId = userId
            return number
        }
        for contact in contacts{
            for number in contact.numbers{
                if number.userId == userId {
                    return number
                }
            }
        }
        let unknownContact = Contact()
        unknownContact.name = userId
        var unknownNumber = ContactNumber()
        unknownNumber.contact = unknownContact
        unknownNumber.userId = userId
        return unknownNumber
    }
    
    func isNumberRegistered(number:ContactNumber) -> Bool{
        if let numbers = self.registeredNumbers {
            return numbers.containsObject(number.userId)
        }
        return false
    }
    
    func getAppUsers(){
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
                self.registeredNumbers = NSSet(array: result as [String])
            }
        }
    }
    
    func reset() {
        if self.isAuthorized {
            self.getAppUsers()
            self.getContacts()
        }
    }
    
}
