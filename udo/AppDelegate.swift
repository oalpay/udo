//
//  AppDelegate.swift
//  udo
//
//  Created by Osman Alpay on 31/07/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import UIKit

var kUserLoggedInNotification = "UserLoggedInNotification"
var kUserLoggedOutNotification = "UserLoggedOutNotification"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
                            
    var window: UIWindow?
    
    var reminderManager:ReminderManager!
    
    var remindersMainViewController:RemindersMainViewController!

    func application(application: UIApplication!, didFinishLaunchingWithOptions launchOptions: NSDictionary!) -> Bool {
        Parse.setApplicationId("ZfTTFTJ49Sb3mJK2Xbi5lw1nhcNsUnO4ayEXP565", clientKey: "nHWUQHYcfkSG1mZNLZqSc35nNpgQ9taEdz46EoE2")
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
        PFConfig.getConfigInBackgroundWithBlock { (_, error:NSError!) -> Void in
            if error != nil {
                println("e:getConfigInBackgroundWithBlock:\(error.localizedDescription)")
            }
        }
        self.window?.tintColor = AppTheme.tintColor
        
        var nc = self.window?.rootViewController as UINavigationController
        self.remindersMainViewController = nc.viewControllers[0] as RemindersMainViewController
        
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
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "userLoggedIn:", name: kUserLoggedInNotification, object: nil)
        
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
        if application.applicationState == UIApplicationState.Active {
              UIAlertView(title: "Alert", message: notification.alertBody, delegate: nil, cancelButtonTitle: "Ok").show()
        }
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        if let userInfo =  launchOptions?[UIApplicationLaunchOptionsLocalNotificationKey] as? NSDictionary {
            if let  reminderId = userInfo["reminderId"] as? NSString{
                self.remindersMainViewController.showReminder(reminderId)
            }
        }
        return true
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        println("helloo")
    }

    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        PFPush.handlePush(userInfo)
        self.reminderManager.remoteNotificationReceived(application.applicationState, userInfo: userInfo, completionHandler: completionHandler)
        if (application.applicationState == UIApplicationState.Inactive) {
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
            if let reminderId = userInfo["r"] as? NSString{
                self.remindersMainViewController.showReminder(reminderId)
            }
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
    }

    func applicationWillEnterForeground(application: UIApplication!) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
         self.reminderManager.applicationWillEnterForegroundNotification()
    }

    func applicationDidBecomeActive(application: UIApplication!) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if PFUser.currentUser() != nil {
            EventStoreManager.sharedInstance.reset()
            self.clearBadge()
        }
    }

    func applicationWillTerminate(application: UIApplication!) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        PFQuery.clearAllCachedResults()
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



}

