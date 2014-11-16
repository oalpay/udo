//
//  LocalNotificationsManager.swift
//  udo
//
//  Created by Osman Alpay on 05/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class LocalNotificationsManager : NSObject{
    
    func removeAll(){
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    func getLocationNotificationForKey(key:String) -> UILocalNotification?{
        var localNotifications = UIApplication.sharedApplication().scheduledLocalNotifications as [UILocalNotification]
        for notification in localNotifications {
            if let userInfo = notification.userInfo as NSDictionary? {
                if let objectId =  userInfo.objectForKey("reminderId") as? String {
                    if objectId == key {
                        return notification
                    }
                }
            }
        }
        return nil
    }
    
    func setLocalNotificationForKey(key:String,alertBodyOption:String?,fireDateOption:NSDate?,repeatInterval:NSNumber?){
        // check if already exists
        if let notification = self.getLocationNotificationForKey(key){
            var cancel = false
            if alertBodyOption == nil  || notification.alertBody != alertBodyOption! {
                cancel = true
            }
            if (notification.fireDate != nil && fireDateOption == nil) || (notification.fireDate == nil && fireDateOption != nil) || !notification.fireDate!.isEqualToDate(fireDateOption!) {
                cancel = true
            }
            if (notification.repeatInterval != nil && repeatInterval == nil) || (notification.repeatInterval == nil && repeatInterval != nil) || notification.repeatInterval.rawValue != repeatInterval{
                cancel = true
            }
            if cancel {
                UIApplication.sharedApplication().cancelLocalNotification(notification)
            }else {
                // not modified
                return
            }
        }
        var now = NSDate()
        if fireDateOption == nil || alertBodyOption == nil || fireDateOption!.laterDate(now) == now {
            return
        }
        var  notification = UILocalNotification()
        notification.alertBody = alertBodyOption!
        notification.fireDate = fireDateOption!
        if repeatInterval != nil {
            notification.repeatInterval = NSCalendarUnit(repeatInterval!.unsignedLongValue)
        }
        notification.userInfo =  NSDictionary(object: key, forKey: "reminderId")
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
    }
    
    func cancelLocalNotificationForKey(key:String){
        if let localNotification = self.getLocationNotificationForKey(key) {
            UIApplication.sharedApplication().cancelLocalNotification(localNotification)
        }
    }
}