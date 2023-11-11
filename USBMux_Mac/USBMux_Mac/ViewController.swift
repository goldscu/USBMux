//
//  ViewController.swift
//  USBMux_Mac
//
//  Created by 黄镇(72163106) on 2023/9/6.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    let videoDecoder = HZVideoDecoder(videoCodecType: kCMVideoCodecType_H264)
    let usbMuxManager = USBMuxManager.shared()
    var usbMuxDevice: USBMuxDevice? = nil
    let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.wantsLayer = true
        self.sampleBufferDisplayLayer.frame = self.view.bounds
        self.sampleBufferDisplayLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        self.view.layer?.addSublayer(self.sampleBufferDisplayLayer)
        
        self.usbMuxManager.delegate = self
        self.usbMuxManager.startListenUSB()
        
        self.videoDecoder.delegate = self
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        self.sampleBufferDisplayLayer.frame = self.view.bounds
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func button1DidTouchUpInside(_ sender: Any) {
        self.usbMuxDevice?.connect(toPort: Int(HZUSBMuxPort), with: self)
    }
    
    @IBAction func button2DidTouchUpInside(_ sender: Any) {
        
    }
}


extension ViewController: USBMuxManagerDelegate {
    func usbMuxManagerDidAttach(_ device: USBMuxDevice) {
        print(#function)
        device.connect(toPort: Int(HZUSBMuxPort), with: self)
        self.usbMuxDevice = device
    }
    
    func usbMuxManagerDidDetach(_ device: USBMuxDevice) {
        if self.usbMuxDevice == device {
            self.usbMuxDevice = nil
        }
        print(#function)
    }
}

extension ViewController: USBMuxDeviceDelegate {
    func usbMuxDeviceDidConnect(_ device: USBMuxDevice) {
        print(#function)
    }
    
    func usbMuxDeviceDidDisconnect(_ device: USBMuxDevice) {
        print(#function)
    }
    
    func usbMuxDevice(_ device: USBMuxDevice, didRead data: Data, from socket: USBMuxSocket) {
        let transferData = HZTransferData(data: data)
        let dataType = transferData.header.dataType
        if dataType == HZTransferDataType.videoData {
            self.videoDecoder.decodeNaluData(transferData.content, presentationTimeStamp: transferData.header.presentationTimeStamp)
        }
    }
    
    func usbMuxDeviceDidWriteData(_ device: USBMuxDevice) {
        print(#function)
    }
}


extension ViewController: HZVideoDecoderDelegate {
    func videoDecoder(_ videoDecoder: HZVideoDecoder, didOutputImageBuffer imageBuffer: CVPixelBuffer, presentationTimeStamp: CMTime) {
        do {
            guard let formatDescription = try? CMVideoFormatDescription(imageBuffer: imageBuffer) else { return }
            let sampleTiming = CMSampleTimingInfo(duration: CMTime.invalid, presentationTimeStamp: presentationTimeStamp, decodeTimeStamp: presentationTimeStamp)
            guard let sampleBuffer = try? CMSampleBuffer(imageBuffer: imageBuffer, formatDescription: formatDescription, sampleTiming: sampleTiming) else { return }
            self.sampleBufferDisplayLayer.enqueue(sampleBuffer)
        }
    }
}
