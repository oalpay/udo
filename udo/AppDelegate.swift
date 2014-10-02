//
//  AppDelegate.swift
//  udo
//
//  Created by Osman Alpay on 31/07/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
                            
    var window: UIWindow?


    func application(application: UIApplication!, didFinishLaunchingWithOptions launchOptions: NSDictionary!) -> Bool {
        Parse.setApplicationId("ZfTTFTJ49Sb3mJK2Xbi5lw1nhcNsUnO4ayEXP565", clientKey: "nHWUQHYcfkSG1mZNLZqSc35nNpgQ9taEdz46EoE2")
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
        PFConfig.getConfigInBackgroundWithBlock(nil)
        
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
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        NSNotificationCenter.defaultCenter().postNotificationName(KReminderPushReceivedNotification, object: nil)
        PFPush.handlePush(userInfo)
        self.clearBadge()
    }
    

    func applicationWillResignActive(application: UIApplication!) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication!) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication!) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication!) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if PFUser.currentUser() != nil {
            ContactsHelper.sharedInstance.reset()
            self.clearBadge()
            NSNotificationCenter.defaultCenter().postNotificationName(KReminderPushReceivedNotification, object: nil)
        }
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


}

