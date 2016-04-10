//
//  BookTableViewController.swift
//  books
//
//  Created by Andrew Bennet on 09/11/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import UIKit
import AVFoundation

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var cameraPreviewPlaceholder: UIView!
    
    let session = AVCaptureSession()
    var bookReadState: BookReadState!
    var previewLayer: AVCaptureVideoPreviewLayer?
    var detectedIsbn13: String?
    
    @IBAction func cancelWasPressed(sender: UIBarButtonItem) {
        session.stopRunning()
        presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewDidLoad() {
        // The phrase "Scan Barcode" is a bit long for the back button: use "Scan" instead.
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Scan", style: .Plain, target: nil, action: nil)
        
        // Setup the camera preview on another thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.setupAvSession()
        }
        
        super.viewDidLoad()
    }
    
    private func setupAvSession(){
        // Setup the input
        let input: AVCaptureDeviceInput!
        do {
            // The default device with Video media type is the camera
            input = try AVCaptureDeviceInput(device: AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo))
            self.session.addInput(input)
        }
        catch {
            // TODO: Handle this error properly
            print("AVCaptureDeviceInput failed to initialise.")
            self.navigationController?.popViewControllerAnimated(true)
        }
        
        // Prepare the metadata output and add to the session
        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
        self.session.addOutput(output)
        output.metadataObjectTypes = output.availableMetadataObjectTypes
        
        // We want to view what the camera is seeing
        previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        previewLayer!.frame = self.cameraPreviewPlaceholder.frame
        previewLayer!.videoGravity = AVLayerVideoGravityResize
        dispatch_async(dispatch_get_main_queue()) {
            self.view.layer.addSublayer(self.previewLayer!)
        }
        
        // Start the scanner. We'll end it once we catch anything.
        self.session.startRunning()
    }
    
    // This is called when we find a known barcode type with the camera.
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        
        // The scanner is capable of capturing multiple 2-dimensional barcodes in one scan.
        // Filter out everything which is not a EAN13 code.
        let ean13MetadataObjects = metadataObjects.filter {
            return $0.type == AVMetadataObjectTypeEAN13Code
        }
        
        if let avMetadata = ean13MetadataObjects.first as? AVMetadataMachineReadableCodeObject{
            // Store the detected value of the barcode
            detectedIsbn13 = avMetadata.stringValue
            
            // Since we have a result, stop the session and pop to the next page
            self.session.stopRunning()
            performSegueWithIdentifier("isbnDetectedSegue", sender: self)
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        if let connection = self.previewLayer?.connection {
            if connection.supportsVideoOrientation {
                switch UIDevice.currentDevice().orientation {
                case .Portrait:
                    connection.videoOrientation = AVCaptureVideoOrientation.Portrait
                    break
                case .LandscapeRight:
                    connection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
                    break
                case .LandscapeLeft:
                    connection.videoOrientation = AVCaptureVideoOrientation.LandscapeLeft
                    break
                case .PortraitUpsideDown:
                    connection.videoOrientation = AVCaptureVideoOrientation.PortraitUpsideDown
                    break
                default:
                    connection.videoOrientation = AVCaptureVideoOrientation.Portrait
                    break
                }
            }                
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "isbnDetectedSegue" {
            let searchResultsController = segue.destinationViewController as! SearchResultsViewController
            searchResultsController.isbn13 = detectedIsbn13!
            searchResultsController.bookReadState = bookReadState
        }
    }
}