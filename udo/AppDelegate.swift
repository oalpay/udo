//
//  AppDelegate.swift
//  udo
//
//  Created by Osman Alpay on 31/07/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics


var kUserLoggedInNotification = "UserLoggedInNotification"
var kUserLoggedOutNotification = "UserLoggedOutNotification"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var nc = NSNotificationCenter.defaultCenter()
    var reminderManager:ReminderManager!
    
    func application(application: UIApplication!, didFinishLaunchingWithOptions launchOptions: NSDictionary!) -> Bool {
        Parse.setApplicationId("ZfTTFTJ49Sb3mJK2Xbi5lw1nhcNsUnO4ayEXP565", clientKey: "nHWUQHYcfkSG1mZNLZqSc35nNpgQ9taEdz46EoE2")
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
        PFConfig.getConfigInBackgroundWithBlock { (_, error:NSError!) -> Void in
            if error != nil {
                println("e:getConfigInBackgroundWithBlock:\(error.localizedDescription)")
            }
        }
        Fabric.with([Crashlytics()])
        
        self.window?.tintColor = AppTheme.tintColor
        
        var nc = self.window?.rootViewController as UINavigationController
        TSMessage.setDefaultViewController(nc)
        
        if (application.applicationState != UIApplicationState.Background) {
            // Track an app open here if we launch with a push, unless
            // "content_available" was used to trigger a background push (introduced
            // in iOS 7). In that case, we skip tracking here to avoid double
            // counting the app-open.
            var preBackgroundPush = !application.respondsToSelector("backgroundRefreshStatus")
            var noPushPayload = true
            if let lo = launchOptions {
                if lo.objectForKey(UIApplicationLaunchOptionsRemoteNotificationKey) == nil {
                    noPushPayload = false
                }
            }
            if (preBackgroundPush || noPushPayload) {
                PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
            }
        }
        
        self.nc.addObserver(self, selector: "userLoggedIn:", name: kUserLoggedInNotification, object: nil)
        
        if PFUser.currentUser() != nil {
            self.registerToPushNotifications()
        }
        self.reminderManager = ReminderManager.sharedInstance
        self.reminderManager.applicationDidFinishLaunchingNotification()
        
        return true
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        // Store the deviceToken in the current installation and save it to Parse.
        var currentInstallation = PFInstallation.currentInstallation()
        currentInstallation.setDeviceTokenFromData(deviceToken)
        currentInstallation.channels =  ["global"]
        currentInstallation["username"] = PFUser.currentUser().username
        currentInstallation.saveEventually()
    }
    
    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        self.reminderManager.localNotificationRecevied(application, notification: notification)
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        if let userInfo =  launchOptions?[UIApplicationLaunchOptionsLocalNotificationKey] as? NSDictionary {
            if let  reminderId = userInfo["reminderId"] as? NSString{
                NSNotificationCenter.defaultCenter().postNotificationName(kReminderShowNotification, object: reminderId)
            }
        }
        return true
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
    }
    
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        let pushInfo = PushNotificationUserInfo(fromUserInfo: userInfo)
        if pushInfo.command != nil {
            let pushInfo = PushNotificationUserInfo(fromUserInfo: userInfo)
            self.reminderManager.remoteNotificationReceived(pushInfo, application: application,fetchCompletionHandler: completionHandler)
        }else {
            if pushInfo.alert != nil {
                TSMessage.showNotificationWithTitle( pushInfo.alert, type: TSMessageNotificationType.Message)
            }
            completionHandler(UIBackgroundFetchResult.NoData)
        }
        if (application.applicationState == UIApplicationState.Inactive) {
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
        }
    }
    
    
    func applicationWillResignActive(application: UIApplication!) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication!) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        //force cache refresh
        /*
        if PFUser.currentUser() != nil {
        var bgTask:UIBackgroundTaskIdentifier!
        bgTask = application.beginBackgroundTaskWithExpirationHandler({ () -> Void in
        PFQuery.clearAllCachedResults()
        application.endBackgroundTask(bgTask)
        bgTask = UIBackgroundTaskInvalid
        })
        self.clearBadge()
        self.reminderManager.refresh { (_, _) -> Void in
        application.endBackgroundTask(bgTask)
        bgTask = UIBackgroundTaskInvalid
        }
        }*/
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func applicationWillEnterForeground(application: UIApplication!) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        self.reminderManager.applicationWillEnterForeground()
        self.clearBadge()
    }
    
    func applicationDidBecomeActive(application: UIApplication!) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication!) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func clearBadge(){
        var currentInstallation = PFInstallation.currentInstallation()
        if currentInstallation.badge != 0 {
            currentInstallation.badge = 0
            currentInstallation.saveEventually()
        }
    }
    
    func userLoggedIn(notification:NSNotification){
        self.registerToPushNotifications()
    }
    
    func registerToPushNotifications(){
        var application = UIApplication.sharedApplication()
        // Register for Push Notitications, if running iOS 8
        if (application.respondsToSelector("registerUserNotificationSettings:")) {
            var userNotificationTypes = UIUserNotificationType.Alert | UIUserNotificationType.Badge | UIUserNotificationType.Sound
            var settings =  UIUserNotificationSettings(forTypes: userNotificationTypes, categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        } else {
            // Register for Push Notifications before iOS 8
            application.registerForRemoteNotificationTypes(UIRemoteNotificationType.Alert | UIRemoteNotificationType.Badge | UIRemoteNotificationType.Sound)
        }
    }
    func isNotificationsEnabled() -> Bool {
        if UIDevice.currentDevice().model == "iPhone Simulator" {
            return true
        }
        let application = UIApplication.sharedApplication()
        var types:UIRemoteNotificationType!
        if application.respondsToSelector("isRegisteredForRemoteNotifications") {
            return application.isRegisteredForRemoteNotifications()
        } else {
            types = UIApplication.sharedApplication().enabledRemoteNotificationTypes()
            return types != UIRemoteNotificationType.None
            
        }
    }
}


enum PushCommand : String {
    case New = "n"
    case Update = "u"
    case Done = "d"
    case Undone = "o"
    case Delivery = "e"
    case Note = "t"
}

enum PushNotificationConstants : String {
    case Command = "c"
    case ReminderId = "r"
    case NoteId = "n"
    case Timestamp = "t"
    case ReminderDueDate = "d"
    case ReminderDueDateInterval = "i"
    case ReminderTitle = "l"
    case Sender = "u"
    case Alert = "alert"
    case Aps = "aps"
}


class PushNotificationUserInfo{
    let command:PushCommand!
    let noteId:String!
    let noteCreatedAt:NSDate!
    let noteTitle:String!
    let reminderId:String!
    let reminderUpdatedAt:NSDate!
    let reminderDueDate:NSDate!
    let reminderDueDateInterval:NSNumber!
    let reminderTitle:String!
    let senderId:String!
    let alert:String!
    
    
    init(fromUserInfo:NSDictionary){
        if let commandString = fromUserInfo[PushNotificationConstants.Command.rawValue] as? String {
            self.command = PushCommand(rawValue: commandString)
        }
        self.reminderId = fromUserInfo[PushNotificationConstants.ReminderId.rawValue] as? String
        self.noteId = fromUserInfo[PushNotificationConstants.NoteId.rawValue] as? String
        if let timestamp = fromUserInfo[PushNotificationConstants.Timestamp.rawValue] as? NSNumber {
             self.reminderUpdatedAt = NSDate(timeIntervalSince1970: timestamp.doubleValue / 1000 )
        }
        self.noteCreatedAt = NSDate()
        if let dueDateTimestamp = fromUserInfo[PushNotificationConstants.ReminderDueDate.rawValue] as? NSNumber {
           self.reminderDueDate = NSDate(timeIntervalSince1970: dueDateTimestamp.doubleValue / 1000 )
        }
        self.reminderDueDateInterval = fromUserInfo[PushNotificationConstants.ReminderDueDateInterval.rawValue] as? NSNumber
        self.reminderTitle = fromUserInfo[PushNotificationConstants.ReminderTitle.rawValue] as? String
        self.senderId = fromUserInfo[PushNotificationConstants.Sender.rawValue] as? String
        if let aps = fromUserInfo[PushNotificationConstants.Aps.rawValue] as? NSDictionary{
            self.alert = aps[PushNotificationConstants.Alert.rawValue] as? String
        }
        if self.command == PushCommand.Note {
            let stringsAfterFirstSemicolon = self.alert.componentsSeparatedByString(":")
            var noteTitle = ""
            for var index = 1; index < stringsAfterFirstSemicolon.count; index++ {
                if index > 1 {
                    noteTitle += ":"
                }
                noteTitle += stringsAfterFirstSemicolon[index]
            }
            self.noteTitle =  noteTitle
        }
    }

}




