//
//  ViewController.swift
//  AVCamSwift
//
//  Created by sunset on 14-11-9.
//  Copyright (c) 2014年 sunset. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary
import AudioToolbox
import CoreLocation
import SystemConfiguration



var SessionRunningAndDeviceAuthorizedContext = "SessionRunningAndDeviceAuthorizedContext"
var CapturingStillImageContext = "CapturingStillImageContext"
var RecordingContext = "RecordingContext"


class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate,CLLocationManagerDelegate, AVCaptureMetadataOutputObjectsDelegate {
    
    // MARK: property
    
    var sessionQueue: dispatch_queue_t!
    var session: AVCaptureSession?
    var captureMetadataOutput: AVCaptureMetadataOutput?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var videoDeviceInput: AVCaptureDeviceInput?
    var movieFileOutput: AVCaptureMovieFileOutput?
    var stillImageOutput: AVCaptureStillImageOutput?
    var deviceAuthorized: Bool  = false
    var backgroundRecordId: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var sessionRunningAndDeviceAuthorized: Bool {
        get {
            return (self.session?.running != nil && self.deviceAuthorized )
        }
    }
    let locationManager = CLLocationManager()
    var runtimeErrorHandlingObserver: AnyObject?
    var lockInterfaceRotation: Bool = true
    var beacons: [CLBeacon] = []
    var currentSticker = ""
    var newSticker = ""
    var msg = "Saved to Camera roll"
    let supportedBarCodes = [AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode, AVMetadataObjectTypeDataMatrixCode]
    
    @IBOutlet weak var capturedImageView: UIImageView!

    @IBOutlet weak var activityViewIndicator: UIActivityIndicatorView!
    @IBOutlet weak var stickerImage: UIImageView!
    @IBOutlet weak var previewView: AVCamPreviewView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var snapButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    @IBAction func retryTapped(sender: UIButton) {
        (self.previewView.layer as! AVCaptureVideoPreviewLayer).connection.enabled=true;
        enableCamera();
        self.capturedImageView.hidden = true;
    }
    @IBAction func downloadTapped(sender: UIButton) {
        UIGraphicsBeginImageContextWithOptions(previewView.frame.size, false, 0.0)
        self.view.makeToast(message: msg)

        previewView.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        
        //ALSO ADD image captured with captureStillImageAsynchronouslyFromConnection right here to the context.
        let image = UIGraphicsGetImageFromCurrentImageContext()

    
        
        //Save it to the camera roll
        
        UIImageWriteToSavedPhotosAlbum(image,nil, nil, nil)
    }
    
    @IBAction func shareTapped(sender: UIButton) {
        UIGraphicsBeginImageContextWithOptions(previewView.frame.size, false, 0.0)
        previewView.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        socialShare(image)
    }
    
    func changeSticker(major: String, minor: String){
        currentSticker = major+minor
        NSLog(currentSticker)

        if let checkedUrl = NSURL(string: "http://s3.amazonaws.com/snappie.watermarks/"+currentSticker+".png") {
            downloadImage(checkedUrl)
        }
        self.activityViewIndicator.hidden=false
        self.activityViewIndicator.startAnimating()
    }


    func getDataFromUrl(url:NSURL, completion: ((data: NSData?, response: NSURLResponse?, error: NSError? ) -> Void)) {
        NSURLSession.sharedSession().dataTaskWithURL(url) { (data, response, error) in
            completion(data: data, response: response, error: error)
            }.resume()
    }
    
    //Create a function to download the image (start the task)

    func downloadImage(url: NSURL){
        print("Started downloading \"\(url.URLByDeletingPathExtension!.lastPathComponent!)\".")
        getDataFromUrl(url) { (data, response, error)  in
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                guard let data = data where error == nil else {
                    let alert = UIAlertController(title: "Could not load Snappie", message: error!.localizedDescription
                        , preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                    self.activityViewIndicator.stopAnimating()
                    self.activityViewIndicator.hidden=true
                    return }
                if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self.stickerImage.image = UIImage(data: data)
                    } else {
                        let alert = UIAlertController(title: "Could not load Snappie", message: "Perhaps this Snappie Sticker is empty?"
                            , preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                        self.presentViewController(alert, animated: true, completion: nil)

                    }
                }
                print("Finished downloading \"\(url.URLByDeletingPathExtension!.lastPathComponent!)\".")
                self.activityViewIndicator.stopAnimating()
                self.activityViewIndicator.hidden=true
                return
            }
        }
    }
    
    func updateView(note: NSNotification!){
        beacons = note.object! as! [CLBeacon]
        let major = beacons[0].major as NSNumber
        let majorString = major.stringValue
        
        let minor = beacons[0].minor as NSNumber
        let minorString = minor.stringValue

        changeSticker(majorString, minor: minorString)
    }
    
    
    // MARK: Override methods
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let session: AVCaptureSession = AVCaptureSession()
        let captureMetadataOutput = AVCaptureMetadataOutput()
        
        /*let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)

        do {
            
            //QR Code stuff's
            let input = try AVCaptureDeviceInput(device: captureDevice)
            session.addInput(input)
  
            let captureMetadataOutput = AVCaptureMetadataOutput()
            session.addOutput(captureMetadataOutput)

=
            //Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
            captureMetadataOutput.metadataObjectTypes = supportedBarCodes
            
        } catch {
            print(error)
            return
        }
*/

        
        self.session = session
        self.captureMetadataOutput = captureMetadataOutput
        self.previewView.session = session
        self.activityViewIndicator.hidden = true
        
        self.checkDeviceAuthorizationStatus()
        
        // Do any additional setup after loading the view, typically from a nib.
        //self.capturedImageView.contentMode = UIViewContentMode.ScaleAspectFit
        //self.capturedImageView = UIImageView(frame: self.previewView.frame)
        let sessionQueue: dispatch_queue_t = dispatch_queue_create("session queue",DISPATCH_QUEUE_SERIAL)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateView:", name: "updateBeaconList", object: nil)

        self.sessionQueue = sessionQueue
        dispatch_async(sessionQueue, {
            self.backgroundRecordId = UIBackgroundTaskInvalid
            self.retryButton.hidden=true;
            self.retryButton.enabled=false;
            self.recordButton.hidden=true;
            self.recordButton.enabled=false;
            //self.downloadButton.hidden=true;
            //self.downloadButton.enabled=false;
            self.shareButton.hidden=true;
            self.shareButton.enabled=false;
            self.downloadButton.hidden=true;
            self.downloadButton.enabled=false;
            let videoDevice: AVCaptureDevice! = ViewController.deviceWithMediaType(AVMediaTypeVideo, preferringPosition: AVCaptureDevicePosition.Back)
            var error: NSError? = nil
            

            
            var videoDeviceInput: AVCaptureDeviceInput?
            do {
                videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            } catch let error1 as NSError {
                error = error1
                videoDeviceInput = nil
            } catch {
                fatalError()
            }
            
            if (error != nil) {
                print(error)
                let alert = UIAlertController(title: "Error", message: error!.localizedDescription
                    , preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
            }
            

            if session.canAddInput(videoDeviceInput){
                session.addInput(videoDeviceInput)
                session.addOutput(captureMetadataOutput)
                captureMetadataOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
                captureMetadataOutput.metadataObjectTypes = self.supportedBarCodes

                self.videoDeviceInput = videoDeviceInput
                
                dispatch_async(dispatch_get_main_queue(), {
                    // Why are we dispatching this to the main queue?
                    // Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView can only be manipulated on main thread.
                    // Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.

                    let orientation: AVCaptureVideoOrientation =  AVCaptureVideoOrientation(rawValue: self.interfaceOrientation.rawValue)!
                    
                    
                    (self.previewView.layer as! AVCaptureVideoPreviewLayer).connection.videoOrientation = orientation
                    
                })
                
            }
            
            
            let audioDevice: AVCaptureDevice = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio).first as! AVCaptureDevice
            
            var audioDeviceInput: AVCaptureDeviceInput?
            
            do {
                videoDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            } catch let error2 as NSError {
                error = error2
                audioDeviceInput = nil
            } catch {
                fatalError()
            }
            
            if error != nil{
                print(error)
                let alert = UIAlertController(title: "Error", message: error!.localizedDescription
                    , preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
            }
            if session.canAddInput(audioDeviceInput){
                session.addInput(audioDeviceInput)
            }
            
            
            
            let movieFileOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieFileOutput){
                session.addOutput(movieFileOutput)

                
                let connection: AVCaptureConnection? = movieFileOutput.connectionWithMediaType(AVMediaTypeVideo)
                let stab = connection?.supportsVideoStabilization
                if (stab != nil) {
                    connection!.enablesVideoStabilizationWhenAvailable = true
                }
                
                self.movieFileOutput = movieFileOutput
                
            }

            let stillImageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
            if session.canAddOutput(stillImageOutput){
                stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
                session.addOutput(stillImageOutput)
                
                self.stillImageOutput = stillImageOutput
            }
            
            
        })
        
        
    }
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects == nil || metadataObjects.count == 0 {
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedBarCodes.contains(metadataObj.type) {
            if metadataObj.stringValue != nil && metadataObj.stringValue != currentSticker {
                changeSticker(metadataObj.stringValue, minor: "")
                NSLog(metadataObj.stringValue)
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                self.currentSticker=metadataObj.stringValue

            }
        }
    }

    
    override func viewWillAppear(animated: Bool) {
        dispatch_async(self.sessionQueue, {
            
 
            
            self.addObserver(self, forKeyPath: "sessionRunningAndDeviceAuthorized", options: [.Old , .New] , context: &SessionRunningAndDeviceAuthorizedContext)
            self.addObserver(self, forKeyPath: "stillImageOutput.capturingStillImage", options:[.Old , .New], context: &CapturingStillImageContext)
            self.addObserver(self, forKeyPath: "movieFileOutput.recording", options: [.Old , .New], context: &RecordingContext)
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "subjectAreaDidChange:", name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: self.videoDeviceInput?.device)
            
            
            weak var weakSelf = self
            
            self.runtimeErrorHandlingObserver = NSNotificationCenter.defaultCenter().addObserverForName(AVCaptureSessionRuntimeErrorNotification, object: self.session, queue: nil, usingBlock: {
                (note: NSNotification?) in
                let strongSelf: ViewController = weakSelf!
                dispatch_async(strongSelf.sessionQueue, {
//                    strongSelf.session?.startRunning()
                    if let sess = strongSelf.session{
                        sess.startRunning()
                    }
//                    strongSelf.recordButton.title  = NSLocalizedString("Record", "Recording button record title")
                })
                
            })
            
            self.session?.startRunning()
            
        })
    }
    
    override func viewWillDisappear(animated: Bool) {
        
        dispatch_async(self.sessionQueue, {
            
            if let sess = self.session{
                sess.stopRunning()
                
                NSNotificationCenter.defaultCenter().removeObserver(self, name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: self.videoDeviceInput?.device)
                NSNotificationCenter.defaultCenter().removeObserver(self.runtimeErrorHandlingObserver!)
                
                self.removeObserver(self, forKeyPath: "sessionRunningAndDeviceAuthorized", context: &SessionRunningAndDeviceAuthorizedContext)
                
                self.removeObserver(self, forKeyPath: "stillImageOutput.capturingStillImage", context: &CapturingStillImageContext)
                self.removeObserver(self, forKeyPath: "movieFileOutput.recording", context: &RecordingContext)
                
                
            }

            
            
        })
        
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        
        (self.previewView.layer as! AVCaptureVideoPreviewLayer).connection.videoOrientation = AVCaptureVideoOrientation(rawValue: toInterfaceOrientation.rawValue)!
        
//        if let layer = self.previewView.layer as? AVCaptureVideoPreviewLayer{
//            layer.connection.videoOrientation = self.convertOrientation(toInterfaceOrientation)
//        }
        
    }
    
    override func shouldAutorotate() -> Bool {
        return !self.lockInterfaceRotation
    }
//    observeValueForKeyPath:ofObject:change:context:
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        

        
        if context == &CapturingStillImageContext{
            let isCapturingStillImage: Bool = change![NSKeyValueChangeNewKey]!.boolValue
            if isCapturingStillImage {
                self.runStillImageCaptureAnimation()
            }
            
        }else if context  == &RecordingContext{
            let isRecording: Bool = change![NSKeyValueChangeNewKey]!.boolValue
            
            dispatch_async(dispatch_get_main_queue(), {
                
                if isRecording {
                    self.recordButton.titleLabel!.text = "Stop"
                    self.recordButton.enabled = true
//                    self.snapButton.enabled = false
                    self.cameraButton.enabled = false
                    
                }else{
//                    self.snapButton.enabled = true

                    self.recordButton.titleLabel!.text = "Record"
                    self.recordButton.enabled = true
                    self.cameraButton.enabled = true
                    
                }
                
                
            })
            
            
        }
        
        else{
            return super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
        
    }
    
 
    func socialShare(image: UIImage) {
        var sharingItems = [AnyObject]()

        if (image != 0) {
            sharingItems.append(image)
        }
        
        let activityViewController = UIActivityViewController(activityItems: sharingItems, applicationActivities:nil)
        activityViewController.excludedActivityTypes = [UIActivityTypeCopyToPasteboard,UIActivityTypeAirDrop,UIActivityTypeAddToReadingList,UIActivityTypeAssignToContact,UIActivityTypePostToTencentWeibo,UIActivityTypePostToVimeo,UIActivityTypePrint,UIActivityTypeSaveToCameraRoll,UIActivityTypePostToWeibo]
        self.presentViewController(activityViewController, animated: true, completion: nil)
    }
    
    
    // MARK: Selector
    func subjectAreaDidChange(notification: NSNotification){
        let devicePoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
        self.focusWithMode(AVCaptureFocusMode.ContinuousAutoFocus, exposureMode: AVCaptureExposureMode.ContinuousAutoExposure, point: devicePoint, monitorSubjectAreaChange: false)
    }
    
    // MARK:  Custom Function
    
    func focusWithMode(focusMode:AVCaptureFocusMode, exposureMode:AVCaptureExposureMode, point:CGPoint, monitorSubjectAreaChange:Bool){
        
        dispatch_async(self.sessionQueue, {
            let device: AVCaptureDevice! = self.videoDeviceInput!.device
  
            do {
                try device.lockForConfiguration()
                
                if device.focusPointOfInterestSupported && device.isFocusModeSupported(focusMode){
                    device.focusMode = focusMode
                    device.focusPointOfInterest = point
                }
                if device.exposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode){
                    device.exposurePointOfInterest = point
                    device.exposureMode = exposureMode
                }
                device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
                
            }catch{
                print(error)
            }
            


            
        })
        
    }
    
    
    
    class func setFlashMode(flashMode: AVCaptureFlashMode, device: AVCaptureDevice){
        
        if device.hasFlash && device.isFlashModeSupported(flashMode) {
            var error: NSError? = nil
            do {
                try device.lockForConfiguration()
                device.flashMode = flashMode
                device.unlockForConfiguration()
                
            } catch let error1 as NSError {
                error = error1
                print(error)
            }
        }
        
    }
    
    func runStillImageCaptureAnimation(){
        dispatch_async(dispatch_get_main_queue(), {
            self.previewView.layer.opacity = 0.0
            print("opacity 0")
            UIView.animateWithDuration(0.25, animations: {
                self.previewView.layer.opacity = 1.0
            print("opacity 1")
            })
        })
    }
    
    class func deviceWithMediaType(mediaType: String, preferringPosition:AVCaptureDevicePosition)->AVCaptureDevice{
        
        var devices = AVCaptureDevice.devicesWithMediaType(mediaType);
        var captureDevice: AVCaptureDevice = devices[0] as! AVCaptureDevice;
        
        for device in devices{
            if device.position == preferringPosition{
                captureDevice = device as! AVCaptureDevice
                break
            }
        }
        
        return captureDevice
        
        
    }
    
    func checkDeviceAuthorizationStatus(){
        let mediaType:String = AVMediaTypeVideo;
        
        AVCaptureDevice.requestAccessForMediaType(mediaType, completionHandler: { (granted: Bool) in
            if granted{
                self.deviceAuthorized = true;
            }else{
                
                dispatch_async(dispatch_get_main_queue(), {
                    let alert: UIAlertController = UIAlertController(
                                                        title: "AVCam",
                                                        message: "AVCam does not have permission to access camera",
                                                        preferredStyle: UIAlertControllerStyle.Alert);
                    
                    let action: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: {
                        (action2: UIAlertAction) in
                        exit(0);
                    } );

                    alert.addAction(action);
                    
                    self.presentViewController(alert, animated: true, completion: nil);
                })
                
                self.deviceAuthorized = false;
            }
        })
        
    }
    

    // MARK: File Output Delegate
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        if(error != nil){
            print(error)
        }
        
        self.lockInterfaceRotation = true
        
        // Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
        
        let backgroundRecordId: UIBackgroundTaskIdentifier = self.backgroundRecordId
        self.backgroundRecordId = UIBackgroundTaskInvalid
        
        ALAssetsLibrary().writeVideoAtPathToSavedPhotosAlbum(outputFileURL, completionBlock: {
            (assetURL:NSURL!, error:NSError!) in
            if error != nil{
                print(error)
                
            }
            
            do {
                try NSFileManager.defaultManager().removeItemAtURL(outputFileURL)
            } catch _ {
            }
            
            if backgroundRecordId != UIBackgroundTaskInvalid {
                UIApplication.sharedApplication().endBackgroundTask(backgroundRecordId)
            }
            
        })
        
        
    }
    
    // MARK: Actions
    
    @IBAction func toggleMovieRecord(sender: AnyObject) {
        
        self.recordButton.enabled = false
        
        /*dispatch_async(self.sessionQueue, {
            if !self.movieFileOutput!.recording{
                self.lockInterfaceRotation = true
                
                if UIDevice.currentDevice().multitaskingSupported {
                    self.backgroundRecordId = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({})
                    
                }
                
                self.movieFileOutput!.connectionWithMediaType(AVMediaTypeVideo).videoOrientation =
                    AVCaptureVideoOrientation(rawValue: (self.previewView.layer as! AVCaptureVideoPreviewLayer).connection.videoOrientation.rawValue )!
                
                // Turning OFF flash for video recording
                ViewController.setFlashMode(AVCaptureFlashMode.Off, device: self.videoDeviceInput!.device)
                
                let outputFilePath: String = NSTemporaryDirectory().stringByAppendingPathComponent( "movie".stringByAppendingPathExtension("mov")!)
                
                self.movieFileOutput!.startRecordingToOutputFileURL(NSURL.fileURLWithPath(outputFilePath), recordingDelegate: self)
                
                
            }else{
                self.movieFileOutput!.stopRecording()
            }
        })*/
        
    }
    
    func enableCamera(){
        snapButton.hidden=false;
        snapButton.enabled=true;
        cameraButton.hidden=false;
        cameraButton.enabled=true;
        retryButton.hidden=true;
        retryButton.enabled=false;
       // downloadButton.hidden=true;
      //  downloadButton.enabled=false;
        shareButton.hidden=true;
        shareButton.enabled=false;
        downloadButton.hidden=true;
        downloadButton.enabled=false;
    }
    
    
    @IBAction func snapStillImage(sender: AnyObject) {
        print("snapStillImage")
        (self.previewView.layer as! AVCaptureVideoPreviewLayer).connection.enabled=false;
        snapButton.hidden=true;
        snapButton.enabled=false;
        cameraButton.hidden=true;
        cameraButton.enabled=false;
        retryButton.hidden=false;
        retryButton.enabled=true;
     //   downloadButton.hidden=false;
    //    downloadButton.enabled=true;
        shareButton.hidden=false;
        shareButton.enabled=true;
        downloadButton.hidden=false;
        downloadButton.enabled=true;
        
        
        
        dispatch_async(self.sessionQueue, {
            // Update the orientation on the still image output video connection before capturing.
            
            let videoOrientation =  (self.previewView.layer as! AVCaptureVideoPreviewLayer).connection.videoOrientation
            
            self.stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = videoOrientation
            
            // Flash set to Auto for Still Capture
            ViewController.setFlashMode(AVCaptureFlashMode.Auto, device: self.videoDeviceInput!.device)

            
            
            self.stillImageOutput!.captureStillImageAsynchronouslyFromConnection(self.stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo), completionHandler: {
                (imageDataSampleBuffer: CMSampleBuffer!, error: NSError!) in
                
                if error == nil {
                    let data:NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                    let image:UIImage = UIImage( data: data)!
                    let flipped_image = UIImage(CGImage: image.CGImage!, scale: CGFloat(1.0), orientation: .LeftMirrored)
                    if self.videoDeviceInput!.device.position == AVCaptureDevicePosition.Front {
                        self.capturedImageView.image = flipped_image
                    } else {
                        self.capturedImageView.image = image
                    }
                    self.capturedImageView.hidden=false;
                    //let capturedImageView = UIImageView(frame: self.previewView.frame)
                    //let libaray:ALAssetsLibrary = ALAssetsLibrary()
                    //let orientation: ALAssetOrientation = ALAssetOrientation(rawValue: self.capturedImage.imageOrientation.rawValue)!
                    //libaray.writeImageToSavedPhotosAlbum(self.capturedImage.CGImage, orientation: orientation, completionBlock: nil)
                    print("captured")
                    
                    
                }else{
//                    print("Did not capture still image")
                    print(error)
                }
                
                
            }) 


        })
    }
    @IBAction func changeCamera(sender: AnyObject) {
        
        
        
        print("change camera")
        
        self.cameraButton.enabled = false
        self.recordButton.enabled = false
        self.snapButton.enabled = false
        
        dispatch_async(self.sessionQueue, {
            
            let currentVideoDevice:AVCaptureDevice = self.videoDeviceInput!.device
            let currentPosition: AVCaptureDevicePosition = currentVideoDevice.position
            var preferredPosition: AVCaptureDevicePosition = AVCaptureDevicePosition.Unspecified
            
            switch currentPosition{
            case AVCaptureDevicePosition.Front:
                preferredPosition = AVCaptureDevicePosition.Back
            case AVCaptureDevicePosition.Back:
                preferredPosition = AVCaptureDevicePosition.Front
            case AVCaptureDevicePosition.Unspecified:
                preferredPosition = AVCaptureDevicePosition.Back
                
            }
            

            
            let device:AVCaptureDevice = ViewController.deviceWithMediaType(AVMediaTypeVideo, preferringPosition: preferredPosition)
            
            var videoDeviceInput: AVCaptureDeviceInput?
            
            do {
                videoDeviceInput = try AVCaptureDeviceInput(device: device)
            } catch _ as NSError {
                videoDeviceInput = nil
            } catch {
                fatalError()
            }
            
            self.session!.beginConfiguration()
            
            self.session!.removeInput(self.videoDeviceInput)
            
            if self.session!.canAddInput(videoDeviceInput){
       
                NSNotificationCenter.defaultCenter().removeObserver(self, name:AVCaptureDeviceSubjectAreaDidChangeNotification, object:currentVideoDevice)
                
                ViewController.setFlashMode(AVCaptureFlashMode.Auto, device: device)
                
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "subjectAreaDidChange:", name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: device)
                                
                self.session!.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
            }else{
                self.session!.addInput(self.videoDeviceInput)
            }
            
            self.session!.commitConfiguration()
            

            
            dispatch_async(dispatch_get_main_queue(), {
                self.recordButton.enabled = true
                self.snapButton.enabled = true
                self.cameraButton.enabled = true
            })
            
        })

        
        
        
    }
    
    @IBAction func focusAndExposeTap(gestureRecognizer: UIGestureRecognizer) {
        
        print("focusAndExposeTap")
        let devicePoint: CGPoint = (self.previewView.layer as! AVCaptureVideoPreviewLayer).captureDevicePointOfInterestForPoint(gestureRecognizer.locationInView(gestureRecognizer.view))
        
        print(devicePoint)
        
        self.focusWithMode(AVCaptureFocusMode.AutoFocus, exposureMode: AVCaptureExposureMode.AutoExpose, point: devicePoint, monitorSubjectAreaChange: true)
        
    }
    @IBAction func handlePan(recognizer:UIPanGestureRecognizer) {
        let translation = recognizer.translationInView(self.view)
        if let view = recognizer.view {
            view.center = CGPoint(x:view.center.x + translation.x,
                y:view.center.y + translation.y)
        }
        recognizer.setTranslation(CGPointZero, inView: self.view)
        if recognizer.state == UIGestureRecognizerState.Ended {
            // 1
            let velocity = recognizer.velocityInView(self.view)
            let magnitude = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
            let slideMultiplier = magnitude / 200
            print("magnitude: \(magnitude), slideMultiplier: \(slideMultiplier)")
            
            // 2
            let slideFactor = 0.1 * slideMultiplier     //Increase for more of a slide
            // 3
            var finalPoint = CGPoint(x:recognizer.view!.center.x + (velocity.x * slideFactor),
                y:recognizer.view!.center.y + (velocity.y * slideFactor))
            // 4
            finalPoint.x = min(max(finalPoint.x, 0), self.view.bounds.size.width)
            finalPoint.y = min(max(finalPoint.y, 0), self.view.bounds.size.height)
            
            // 5
            UIView.animateWithDuration(Double(slideFactor * 2),
                delay: 0,
                // 6
                options: UIViewAnimationOptions.CurveEaseOut,
                animations: {recognizer.view!.center = finalPoint },
                completion: nil)
        }
    }
    
    @IBAction func handlePinch(recognizer : UIPinchGestureRecognizer) {
        if let view = recognizer.view {
            view.transform = CGAffineTransformScale(view.transform,
                recognizer.scale, recognizer.scale)
            recognizer.scale = 1
        }
    }
    
    @IBAction func handleRotate(recognizer : UIRotationGestureRecognizer) {
        if let view = recognizer.view {
            view.transform = CGAffineTransformRotate(view.transform, recognizer.rotation)
            recognizer.rotation = 0
        }
    }
    
    func gestureRecognizer(_: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWithGestureRecognizer:UIGestureRecognizer) -> Bool {
            return true
    }
}
