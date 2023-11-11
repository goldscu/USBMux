//
//  ViewController.m
//  USBMux_iOS
//
//  Created by 黄镇(72163106) on 2023/9/6.
//

#import "ViewController.h"
#import "USBMux.h"
#import "HZTransferData.h"
#import "HZCapture.h"
#import "HZVideoEncoder.h"

@interface ViewController () <USBMuxDeviceDelegate, GCDAsyncSocketDelegate, HZCapturerDelegate, HZVideoEncoderDelegate>

@property (nonatomic, strong) USBMuxDevice *usbMuxDevice;
@property (nonatomic, strong) NSMutableArray<USBMuxSocket *> *clientSocketsArray;
@property (nonatomic, strong) HZCapture *capture;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer1;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer2;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer3;
@property (nonatomic, strong) AVCaptureDevice *device1;
@property (nonatomic, strong) AVCaptureDevice *device2;
@property (nonatomic, strong) AVCaptureDevice *device3;
@property (nonatomic, assign) BOOL shouldSend;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSUInteger size;
@property (nonatomic, strong) HZVideoEncoder *videoEncoder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.usbMuxDevice = [[USBMuxDevice alloc] initWithDelegate:self];
    NSError *error = nil;
    [self.usbMuxDevice acceptOnPort:HZUSBMuxPort error:&error];
    if (error) {
        NSLog(@"usbMuxDevice acceptOnPort error: %@", error);
    }
    self.clientSocketsArray = [NSMutableArray array];
    
    self.sampleBufferDisplayLayer1 = [AVSampleBufferDisplayLayer layer];
    self.sampleBufferDisplayLayer1.frame = self.view.bounds;
    [self.view.layer insertSublayer:self.sampleBufferDisplayLayer1 atIndex:0];
    
    self.sampleBufferDisplayLayer2 = [AVSampleBufferDisplayLayer layer];
    self.sampleBufferDisplayLayer2.frame = CGRectMake(self.view.bounds.size.width / 2, 0.0, self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    [self.view.layer insertSublayer:self.sampleBufferDisplayLayer2 atIndex:0];
    
    self.sampleBufferDisplayLayer3 = [AVSampleBufferDisplayLayer layer];
    self.sampleBufferDisplayLayer3.frame = CGRectMake(0.0, self.view.bounds.size.height / 2, self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    [self.view.layer insertSublayer:self.sampleBufferDisplayLayer3 atIndex:0];
    
    self.videoEncoder = [[HZVideoEncoder alloc] initWithVideoCodecType:kCMVideoCodecType_H264 delegate:self];
    
    NSArray<AVCaptureDevice *> *a1 = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront].devices;
    self.device1 = a1.firstObject;
    NSArray<AVCaptureDevice *> *a2 = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInTelephotoCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack].devices;
    self.device2 = a2.firstObject;
    NSArray<AVCaptureDevice *> *a3 = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInUltraWideCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack].devices;
    self.device3 = a3.firstObject;
    self.capture = [[HZCapture alloc] initWithDelegate:self videoDevices:@[self.device1] audioDevice:nil needsMultiCamera:NO];
    [self.capture startCapture];
    
//    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
//        NSLog(@"%f MB/s", self.size / 1024.0 / 1024.0);
//        self.size = 0;
//    }];
}

- (IBAction)button1DidTouchUpInside:(id)sender {
    
}

- (IBAction)button2DidTouchUpInside:(id)sender {
//    NSArray<USBMuxSocket *> *clientsArray = [self.usbMuxDevice getClientSockets];
//    NSLog(@"Connected count:%lu", (unsigned long)clientsArray.count);
//    if (clientsArray.count > 0) {
//        NSData *data = [self.textField.text dataUsingEncoding:NSUTF8StringEncoding];
//        [self.usbMuxDevice writeData:data useClientSocket:clientsArray.firstObject dataTag:123];
//    }
    
//    if (self.clientSocketsArray.count > 0) {
//        NSData *data = [@"111" dataUsingEncoding:NSUTF8StringEncoding];
//        [self.usbMuxDevice writeData:data useClientSocket:self.clientSocketsArray[0]];
//    }
    
    [self.capture changeSessionPreset:AVCaptureSessionPreset640x480];
}

#pragma mark - USBMuxDeviceDelegate
- (void)usbMuxDevice:(USBMuxDevice *)device didConnectToSocket:(USBMuxSocket *)clientSocket {
    NSLog(@"%s", __func__);
    [self.clientSocketsArray addObject:clientSocket];
}

- (void)usbMuxDevice:(USBMuxDevice *)device clientSocketDidDisconnect:(USBMuxSocket *)clientSocket {
    NSLog(@"%s", __func__);
    if ([self.clientSocketsArray containsObject:clientSocket]) {
        [self.clientSocketsArray removeObject:clientSocket];
    }
}

- (void)usbMuxDevice:(USBMuxDevice *)device didReadData:(NSData *)data withDataTag:(uint32_t)dataTag fromSocket:(USBMuxSocket *)clientSocket {
    NSLog(@"%s %d %@", __func__, dataTag, data);
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"%@", string);
}

- (void)usbMuxDeviceDidWriteData:(USBMuxDevice *)device {
    //NSLog(@"%s", __func__);
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"%s %@", __func__, newSocket);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"%s %@ %d", __func__, host, port);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    NSLog(@"%s %@", __func__, url);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"%s %ld %@ %@", __func__, tag, sock, data);
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"%s %ld %ld", __func__, tag, partialLength);
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"%s %ld", __func__, tag);
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"%s %ld %ld", __func__, tag, partialLength);
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    NSLog(@"%s %ld %f %ld", __func__, tag, elapsed, length);
    return 0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    NSLog(@"%s %ld %f %ld", __func__, tag, elapsed, length);
    return 0;
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    NSLog(@"%s", __func__);
}

- (void)socketDidDisconnect:(USBMuxSocket *)sock withError:(nullable NSError *)err {
    NSLog(@"%s %@ %@", __func__, sock, err);
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    NSLog(@"%s", __func__);
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
    NSLog(@"%s", __func__);
    completionHandler(YES);
}

#pragma mark - HZCapturerDelegate
- (void)capture:(HZCapture *)capture didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer fromDevice:(AVCaptureDevice *)device {
    if (device == self.device1) {
        [self.sampleBufferDisplayLayer1 enqueueSampleBuffer:sampleBuffer];
        [self.videoEncoder encodeSampleBuffer:sampleBuffer forceKeyFrame:NO];
    } else if (device == self.device2) {
        [self.sampleBufferDisplayLayer2 enqueueSampleBuffer:sampleBuffer];
    } else if (device == self.device3) {
        [self.sampleBufferDisplayLayer3 enqueueSampleBuffer:sampleBuffer];
    }
    
//    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
//    void * c_data = CVPixelBufferGetBaseAddress(pixelBuffer);
//    size_t size = CVPixelBufferGetDataSize(pixelBuffer);
//    NSData *data = [NSData dataWithBytes:c_data length:size];
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
////    NSArray<USBMuxSocket *> *clientsArray = [self.usbMuxDevice getClientSockets];
////    if (clientsArray.count > 0 && self.shouldSend) {
////        self.shouldSend = NO;
////        NSLog(@"send: %lu", (unsigned long)data.length);
////        [self.usbMuxDevice writeData:data useClientSocket:clientsArray.firstObject dataTag:123];
////    }
//    self.size += size;
}

- (void)capture:(HZCapture *)capture didOutputAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
}

#pragma mark - HZVideoEncoderDelegate
- (void)videoEncodeDidOutputVpsData:(NSData *)vpsData spsData:(NSData *)spsData ppsDataData:(NSData *)ppsData ppsExtesionData:(nullable NSData *)ppsExtesionData codecType:(CMVideoCodecType)codecType {
    if (self.clientSocketsArray.count > 0) {
        if (vpsData.length > 0) {
            HZTransferData *vpsTransferData = [[HZTransferData alloc] initWithDataType:HZTransferDataTypeVideoData codecType:codecType presentationTimeStamp:0.0 data:vpsData];
            [self.usbMuxDevice writeData:vpsTransferData.all useClientSocket:self.clientSocketsArray[0]];
        }
        
        HZTransferData *spsTransferData = [[HZTransferData alloc] initWithDataType:HZTransferDataTypeVideoData codecType:codecType presentationTimeStamp:0.0 data:spsData];
        [self.usbMuxDevice writeData:spsTransferData.all useClientSocket:self.clientSocketsArray[0]];
        
        HZTransferData *ppsTransferData = [[HZTransferData alloc] initWithDataType:HZTransferDataTypeVideoData codecType:codecType presentationTimeStamp:0.0 data:ppsData];
        [self.usbMuxDevice writeData:ppsTransferData.all useClientSocket:self.clientSocketsArray[0]];
        
        if (ppsExtesionData.length > 0) {
            HZTransferData *ppsExtesionTransferData = [[HZTransferData alloc] initWithDataType:HZTransferDataTypeVideoData codecType:codecType presentationTimeStamp:0.0 data:ppsExtesionData];
            [self.usbMuxDevice writeData:ppsExtesionTransferData.all useClientSocket:self.clientSocketsArray[0]];
        }
    }
}

- (void)videoEncodeDidOutputData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame presentationTimeStamp:(Float64)presentationTimeStamp codecType:(CMVideoCodecType)codecType {
    if (self.clientSocketsArray.count > 0) {
        HZTransferData *frameData = [[HZTransferData alloc] initWithDataType:HZTransferDataTypeVideoData codecType:codecType presentationTimeStamp:presentationTimeStamp data:data];
        [self.usbMuxDevice writeData:frameData.all useClientSocket:self.clientSocketsArray[0]];
    }
}

@end
