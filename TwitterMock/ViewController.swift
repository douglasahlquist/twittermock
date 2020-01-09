//
//  ViewController.swift
//  TwitterMock
//
//  Created by Douglas Ahlquist on 1/8/20.
//  Copyright © 2020 Twitter Next. All rights reserved.
//

import UIKit
import CoreNFC

protocol CustomViewDelegate {
    func imageViewTapped()
}

class ViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    
    var bgImage = UIImage()
    var bgImageView = UIImageView()
    var bgImageName = "douglas"
    var isUserInteractionEnabled = true
    var nfcReadSessionActive = false
    
    /// - Tag: - Properties
    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        bgImageName = "douglas"
        setBackgroundImage()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap(sender:)))
        tapGestureRecognizer.numberOfTapsRequired = 2
        self.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setBackgroundImage() {
        if bgImageName > "" {
            bgImageView.removeFromSuperview()
            bgImage = UIImage(named: bgImageName)!
            bgImageView = UIImageView(frame: self.view.bounds)
            bgImageView.image = bgImage
            self.view.addSubview(bgImageView)
            self.view.sendSubviewToBack(bgImageView)
        }
    }
    
    @objc
    func didTap(sender: UITapGestureRecognizer) {
        
        do{
            beginScanning(self)
        }catch{
            
        }
    }
    
    func tapgesture(_ sender: UITapGestureRecognizer){
         if sender.state == .ended {
            
            beginScanning(self)
            //let touchLocation: CGPoint = sender.location(in: sender.view?.superview)
            //if this.frame.contains(touchLocation) {
               print("tapped method called")
            //delegate?.imageViewTapped()
           // }
        }
    }


    // MARK: beginScanning
    @objc
    func beginScanning(_ sender: Any) {
        
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
    }

    // MARK: NFCNDEFReaderSessionDelegate - processingTagData
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            // Process detected NFCNDEFMessage objects.
            self.detectedMessages.append(contentsOf: messages)
        }
    }

    // MARK: ProcessingNDEFTag
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if(nfcReadSessionActive){
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        // Connect to the found tag and perform NDEF message reading
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                if .notSupported == ndefStatus {
                    session.alertMessage = "Tag is not NDEF compliant"
                    session.invalidate()
                    return
                } else if nil != error {
                    session.alertMessage = "Unable to query NDEF status of tag"
                    session.invalidate()
                    return
                }
                
                tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                    var statusMessage: String
                    if nil != error || nil == message {
                        // You will see this message on the phone when a tag is read that
                        // has not been written to
                        statusMessage = "Fail to read NDEF from tag"
                    } else {
                        statusMessage = "Found 1 NDEF message"
                        DispatchQueue.main.async {
                            // Process detected NFCNDEFMessage objects.
                            self.detectedMessages.append(message!)
                            //self.tableView.reloadData()
                        }
                    }
                    
                    session.alertMessage = statusMessage
                    session.invalidate()
                })
            })
        })
        }
    }
    
    // MARK: sessionBecomeActive
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        nfcReadSessionActive = true
    }
    
    // MARK: endScanning
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Check the invalidation reason from the returned error.
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a
            // successful read during a single-tag read session, or because the
            // user canceled a multiple-tag read session from the UI or
            // programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                let alertController = UIAlertController(
                    title: "Session Invalidated",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }

        // To read new tags, a new session instance is required.
        self.session = nil
    }

    // MARK: - addMessage(fromUserActivity:)
    func addMessage(fromUserActivity message: NFCNDEFMessage) {
        DispatchQueue.main.async {
            self.detectedMessages.append(message)
            print(message)
            //self.tableView.reloadData()
        }
    }
}
