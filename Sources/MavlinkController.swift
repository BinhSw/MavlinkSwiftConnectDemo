//
//  MavlinkController.swift
//  MavlinkSwiftConnectDemo
//
//  Created by Michael Koukoullis on 5/10/2015.
//  Copyright © 2015 Michael Koukoullis. All rights reserved.
//

import Cocoa
import ORSSerial
import ReactiveMavlink

class MavlinkController: NSObject {

    // MARK: Stored Properties
    let reactiveMavlink = ReactiveMavlink()
    
    let serialPortManager = ORSSerialPortManager.sharedSerialPortManager()
	
    var serialPort: ORSSerialPort? {
        didSet {
            oldValue?.close()
            oldValue?.delegate = nil
            serialPort?.delegate = self
            serialPort?.baudRate = 57600
            serialPort?.numberOfStopBits = 1
            serialPort?.parity = .None
        }
    }
    
    // MARK: IBOutlets
	
    @IBOutlet weak var openCloseButton: NSButton!
    @IBOutlet weak var usbRadioButton: NSButton!
    @IBOutlet weak var telemetryRadioButton: NSButton!
    @IBOutlet var receivedMessageTextView: NSTextView!
    @IBOutlet weak var clearTextViewButton: NSButton!
   
    // MARK: Initializers
    
    override init() {
        super.init()
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(MavlinkController.serialPortsWereConnected(_:)), name: ORSSerialPortsWereConnectedNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(MavlinkController.serialPortsWereDisconnected(_:)), name: ORSSerialPortsWereDisconnectedNotification, object: nil)
        
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
        
        reactiveMavlink.heartbeat.observeNext { [weak self] _ in
            self?.receivedMessageTextView.textStorage?.mutableString.appendString("HEARTBEAT\n")
            self?.receivedMessageTextView.needsDisplay = true
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    // MARK: - Actions

    @IBAction func openOrClosePort(sender: AnyObject) {
        guard let port = serialPort else {
            return
        }
        
        if port.open {
            port.close()
        }
        else {
            clearTextView(self)
            port.open()
            
            if usbRadioButton.state != 0 {
                startUsbMavlinkSession()
            }
        }
    }
    
    private func startUsbMavlinkSession() {
        guard let port = self.serialPort where port.open else {
            print("Serial port is not open")
            return
        }
        
        guard let data = "mavlink start -d /dev/ttyACM0\n".dataUsingEncoding(NSUTF32LittleEndianStringEncoding) else {
            print("Cannot create mavlink USB start command")
            return
        }
        
        port.sendData(data)
    }
    
    @IBAction func clearTextView(sender: AnyObject) {
        self.receivedMessageTextView.textStorage?.mutableString.setString("")
    }
    
    @IBAction func radioButtonSelected(sender: AnyObject) {
        // No-op - required to make radio buttons behave as a group
    }
    
    // MARK: - Notifications
    
    func serialPortsWereConnected(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let connectedPorts = userInfo[ORSConnectedSerialPortsKey] as! [ORSSerialPort]
            print("Ports were connected: \(connectedPorts)")
            postUserNotificationForConnectedPorts(connectedPorts)
        }
    }
    
    func serialPortsWereDisconnected(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let disconnectedPorts: [ORSSerialPort] = userInfo[ORSDisconnectedSerialPortsKey] as! [ORSSerialPort]
            print("Ports were disconnected: \(disconnectedPorts)")
            postUserNotificationForDisconnectedPorts(disconnectedPorts)
        }
    }
    
    func postUserNotificationForConnectedPorts(connectedPorts: [ORSSerialPort]) {
        let unc = NSUserNotificationCenter.defaultUserNotificationCenter()
        for port in connectedPorts {
            let userNote = NSUserNotification()
            userNote.title = NSLocalizedString("Serial Port Connected", comment: "Serial Port Connected")
            userNote.informativeText = "Serial Port \(port.name) was connected to your Mac."
            userNote.soundName = nil;
            unc.deliverNotification(userNote)
        }
    }
    
    func postUserNotificationForDisconnectedPorts(disconnectedPorts: [ORSSerialPort]) {
        let unc = NSUserNotificationCenter.defaultUserNotificationCenter()
        for port in disconnectedPorts {
            let userNote = NSUserNotification()
            userNote.title = NSLocalizedString("Serial Port Disconnected", comment: "Serial Port Disconnected")
            userNote.informativeText = "Serial Port \(port.name) was disconnected from your Mac."
            userNote.soundName = nil;
            unc.deliverNotification(userNote)
        }
    }
}

extension MavlinkController: ORSSerialPortDelegate {
    
    func serialPortWasOpened(serialPort: ORSSerialPort) {
        openCloseButton.title = "Close"
    }
    
    func serialPortWasClosed(serialPort: ORSSerialPort) {
        openCloseButton.title = "Open"
    }
    
    func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
        self.serialPort = nil
        self.openCloseButton.title = "Open"
    }
    
    func serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData) {
        reactiveMavlink.receiveData(data)
    }
    
    func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
        print("SerialPort \(serialPort.name) encountered an error: \(error)")
    }
}

extension MavlinkController: NSUserNotificationCenterDelegate {
    
    func userNotificationCenter(center: NSUserNotificationCenter, didDeliverNotification notification: NSUserNotification) {
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(3.0 * Double(NSEC_PER_SEC)))
        dispatch_after(popTime, dispatch_get_main_queue()) { () -> Void in
            center.removeDeliveredNotification(notification)
        }
    }
    
    func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool {
        return true
    }
}
