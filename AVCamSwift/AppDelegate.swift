//
//  AppDelegate.swift
//  AVCamSwift
//
//  Created by sunset on 14-11-9.
//  Copyright (c) 2014年 sunset. All rights reserved.
//

import UIKit
import CoreLocation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var locationManager: CLLocationManager?
    var lastProximity: CLProximity?
    var beacons = []
    var orderedBeacons = []

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        let uuidString = "699EBC80-E1F3-11E3-9A0f-0CF3EE3BC012"
        let beaconIdentifier = "snappie.us"
        let beaconUUID:NSUUID = NSUUID(UUIDString: uuidString)!
        let beaconRegion:CLBeaconRegion = CLBeaconRegion(proximityUUID: beaconUUID,
            identifier: beaconIdentifier)
        
        locationManager = CLLocationManager()
        if(locationManager!.respondsToSelector("requestAlwaysAuthorization")) {
            locationManager!.requestAlwaysAuthorization()
        }
        locationManager!.delegate = self
        locationManager!.pausesLocationUpdatesAutomatically = false
        
        locationManager!.startMonitoringForRegion(beaconRegion)
        locationManager!.startRangingBeaconsInRegion(beaconRegion)
        locationManager!.startUpdatingLocation()
        if(application.respondsToSelector("registerUserNotificationSettings:")) {
            application.registerUserNotificationSettings(
                UIUserNotificationSettings(
                    forTypes: UIUserNotificationType.Alert,
                    categories: nil
                )
            )
        }
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

extension AppDelegate: CLLocationManagerDelegate {
        func sendLocalNotificationWithMessage(message: String!) {
            let notification:UILocalNotification = UILocalNotification()
            notification.alertBody = message
            UIApplication.sharedApplication().scheduleLocalNotification(notification)
        }
    
        func locationManager(manager: CLLocationManager,
            didRangeBeacons beacons: [CLBeacon],
            inRegion region: CLBeaconRegion) {
                NSLog("didRangeBeacons");
                self.beacons = beacons
                let orderedBeacons = beacons.filter{ $0.proximity != CLProximity.Unknown }
                self.orderedBeacons = orderedBeacons
                var message:String = ""
                
                if(beacons.count > 0) {
                    let nearestBeacon:CLBeacon = beacons[0]
                    if(nearestBeacon.proximity == lastProximity ||
                        nearestBeacon.proximity == CLProximity.Unknown) {
                            return;
                    }
                    lastProximity = nearestBeacon.proximity;
                    switch nearestBeacon.proximity {
                    case CLProximity.Far:
                        message = "You are far away from the beacon"
                    case CLProximity.Near:
                        message = "You are near the beacon"
                    case CLProximity.Immediate:
                        message = "Congrats! You've found a Snappie!"
                        sendLocalNotificationWithMessage(message)
                        NSNotificationCenter.defaultCenter().postNotificationName("updateBeaconList", object: self.orderedBeacons)

                    case CLProximity.Unknown:
                        return
                    }
                } else {
                    message = "No beacons are nearby"
                }
                
                NSLog("%@", message)
                //sendLocalNotificationWithMessage(message)
        }
        func locationManager(manager: CLLocationManager,
            didEnterRegion region: CLRegion) {
                manager.startRangingBeaconsInRegion(region as! CLBeaconRegion)
                manager.startUpdatingLocation()
            
                NSLog("You entered the region")
        }
    
        func locationManager(manager: CLLocationManager,
            didExitRegion region: CLRegion) {
                manager.stopRangingBeaconsInRegion(region as! CLBeaconRegion)
                manager.stopUpdatingLocation()
            
                NSLog("You exited the region")
        }
}

extension String {
    
    func stringByAppendingPathComponent(path: String) -> String {
        
        let nsSt = self as NSString
        
        return nsSt.stringByAppendingPathComponent(path)
    }
}
