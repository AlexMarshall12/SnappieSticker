//
//  InstagramShare.swift
//  AVCamSwift
//
//  Created by Alex on 10/2/15.
//  Copyright © 2015 sunset. All rights reserved.
//

import UIKit
import AVFoundation

class ActivityViewCustomActivity: UIActivity {
    
    var customActivityType = ""
    var activityName = ""
    var activityImageName = ""
    var customActionWhenTapped:( (Void)-> Void)!
    
    init(title: String, imageName:String, performAction: (() -> ()) ) {
        self.activityName = title
        self.activityImageName = imageName
        self.customActivityType = "Action \(title)"
        self.customActionWhenTapped = performAction
        super.init()
    }
    
    override func activityType() -> String? {
        return customActivityType
    }
    
    override func activityTitle() -> String? {
        return activityName
    }
    
    override func activityImage() -> UIImage? {
        return UIImage(named: activityImageName)
    }
    
    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        return true
    }
    
    override func prepareWithActivityItems(activityItems: [AnyObject]) {
        // nothing to prepare
    }
    
    override func activityViewController() -> UIViewController? {
        return nil
    }
    
    override func performActivity() {
        customActionWhenTapped()
    }
}