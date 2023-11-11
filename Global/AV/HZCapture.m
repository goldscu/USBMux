//
//  HZCapture.m
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/18.
//

#import "HZCapture.h"


@interface HZCapturePipeline : NSObject

@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureConnection *connection;
@property (nonatomic, strong) AVCaptureOutput *dataOutput;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSDictionary<NSString *, id> *settinsArray;

@end

@implementation HZCapturePipeline

- (instancetype)initWithDevice:(AVCaptureDevice *)device {
    if (self = [super init]) {
        self.device = device;
        NSError *error;
        self.input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (error) {
            NSLog(@"AVCaptureDeviceInput deviceInputWithDevice error: %@", error);
        }
    }
    return self;
}

@end



@interface HZVideoCapturePipeline : HZCapturePipeline

@property (nonatomic, strong) AVCaptureVideoDataOutput *dataOutput;

@end

@implementation HZVideoCapturePipeline
@dynamic dataOutput;

- (instancetype)initWithDevice:(AVCaptureDevice *)device {
    if (self = [super initWithDevice:device]) {
        self.dataOutput = [[AVCaptureVideoDataOutput alloc] init];
        self.dataOutput.videoSettings = @{
            (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        };
        self.dataOutput.alwaysDiscardsLateVideoFrames = YES;
        self.settinsArray = [self.dataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
        
        self.queue = dispatch_queue_create("HZVideoCapturerOutputQueue", DISPATCH_QUEUE_SERIAL);
        
        NSArray<AVCaptureInputPort *> *portsArray = self.input.ports;
        self.connection = [AVCaptureConnection connectionWithInputPorts:portsArray output:self.dataOutput];
        self.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    return self;
}

@end



@interface HZAudioCapturePipeline : HZCapturePipeline

@property (nonatomic, strong) AVCaptureAudioDataOutput *dataOutput;

@end

@implementation HZAudioCapturePipeline
@dynamic dataOutput;

- (instancetype)initWithDevice:(AVCaptureDevice *)device {
    if (self = [super initWithDevice:device]) {
        self.dataOutput = [[AVCaptureAudioDataOutput alloc] init];
        
        self.queue = dispatch_queue_create("HZVideoCapturerOutputQueue", DISPATCH_QUEUE_SERIAL);
        
        NSArray<AVCaptureInputPort *> *portsArray = self.input.ports;
        self.connection = [AVCaptureConnection connectionWithInputPorts:portsArray output:self.dataOutput];
    }
    return self;
}

@end


@interface HZCapture () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
//, AVCaptureDataOutputSynchronizerDelegate
>

//@property (nonatomic, strong) AVCaptureMultiCamSession *captureMultiCamSession;
//@property (nonatomic, strong) AVCaptureDataOutputSynchronizer *dataOutputSynchronizer;

@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) NSMutableArray<HZVideoCapturePipeline *> *videoPipelinesArray;
@property (nonatomic, strong) HZAudioCapturePipeline *audioPipeline;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation HZCapture

+ (NSArray<AVCaptureDevice *> *)devicesWithDeviceType:(AVCaptureDeviceType)deviceType mediaType:(AVMediaType)mediaType position:(AVCaptureDevicePosition)position {
//    NSArray<AVCaptureDeviceType> *deviceTypesArray = @[
//        AVCaptureDeviceTypeBuiltInWideAngleCamera,
//        AVCaptureDeviceTypeBuiltInTelephotoCamera,
//        AVCaptureDeviceTypeBuiltInUltraWideCamera,
//        AVCaptureDeviceTypeBuiltInDualCamera,
//        AVCaptureDeviceTypeBuiltInDualWideCamera,
//        AVCaptureDeviceTypeBuiltInTripleCamera,
//        AVCaptureDeviceTypeBuiltInTrueDepthCamera,
//        AVCaptureDeviceTypeBuiltInLiDARDepthCamera,
//    ];
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[deviceType] mediaType:mediaType position:position];
    return [captureDeviceDiscoverySession devices];
}

- (void)dealloc {
    NSLog(@"dealloc -- HZCapture");
}

- (instancetype)initWithDefaultVideoDeviceAndAudioDeviceAndDelegate:(id<HZCapturerDelegate>)delegate {
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
#if TARGET_OS_IPHONE
    return [self initWithDelegate:delegate videoDevices:@[videoDevice] audioDevice:audioDevice needsMultiCamera:NO];
#elif TARGET_OS_OSX
    return [self initWithDelegate:delegate videoDevice:videoDevice audioDevice:audioDevice];
#endif
}

- (instancetype)initWithDefaultVideoDeviceAndDelegate:(nullable id<HZCapturerDelegate>)delegate {
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
#if TARGET_OS_IPHONE
    return [self initWithDelegate:delegate videoDevices:@[videoDevice] audioDevice:nil needsMultiCamera:NO];
#elif TARGET_OS_OSX
    return [self initWithDelegate:delegate videoDevice:videoDevice audioDevice:nil];
#endif
}

- (instancetype)initWithDefaultAudioDeviceAndDelegate:(nullable id<HZCapturerDelegate>)delegate {
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
#if TARGET_OS_IPHONE
    return [self initWithDelegate:delegate videoDevices:nil audioDevice:audioDevice needsMultiCamera:NO];
#elif TARGET_OS_OSX
    return [self initWithDelegate:delegate videoDevice:nil audioDevice:audioDevice];
#endif
}

#if TARGET_OS_IPHONE
/// iOS支持多个摄像头
- (instancetype)initWithDelegate:(nullable id<HZCapturerDelegate>)delegate videoDevices:(nullable NSArray<AVCaptureDevice *> *)videoDevicesArray audioDevice:(nullable AVCaptureDevice *)audioDevice needsMultiCamera:(BOOL)needsMultiCamera {
    if (self = [super init]) {
        self.delegate = delegate;
        self.videoPipelinesArray = [NSMutableArray array];
        [videoDevicesArray enumerateObjectsUsingBlock:^(AVCaptureDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            HZVideoCapturePipeline *videoCapturePipeline = [[HZVideoCapturePipeline alloc] initWithDevice:obj];
            [self.videoPipelinesArray addObject:videoCapturePipeline];
        }];
        
        if (audioDevice) {
            self.audioPipeline = [[HZAudioCapturePipeline alloc] initWithDevice:audioDevice];
        }
        
        if (needsMultiCamera && [AVCaptureMultiCamSession isMultiCamSupported]) {
            _usingMultiCamera = YES;
            self.captureSession = [[AVCaptureMultiCamSession alloc] init];
            self.captureSession.usesApplicationAudioSession = YES;
        } else {
            self.captureSession = [[AVCaptureSession alloc] init];
        }
        
        self.queue = dispatch_queue_create("HZCapturerOperationQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#elif TARGET_OS_OSX
/// Mac只支持一个摄像头
- (instancetype)initWithDelegate:(nullable id<HZCapturerDelegate>)delegate videoDevice:(nullable AVCaptureDevice *)videoDevice audioDevice:(nullable AVCaptureDevice *)audioDevice {
    if (self = [super init]) {
        self.delegate = delegate;
        self.videoPipelinesArray = [NSMutableArray array];
        HZVideoCapturePipeline *videoCapturePipeline = [[HZVideoCapturePipeline alloc] initWithDevice:videoDevice];
        [self.videoPipelinesArray addObject:videoCapturePipeline];
        
        if (audioDevice) {
            self.audioPipeline = [[HZAudioCapturePipeline alloc] initWithDevice:audioDevice];
        }
        
        self.captureSession = [[AVCaptureSession alloc] init];
        
        self.queue = dispatch_queue_create("HZCapturerOperationQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
#endif

- (void)addPipeline:(HZCapturePipeline *)pipeline  {
    if ([self.captureSession canAddInput:pipeline.input]) {
        [self.captureSession addInputWithNoConnections:pipeline.input];
    } else {
        NSLog(@"不能添加 %@ 设备", pipeline.device.class);
        return;
    }
    
    if ([self.captureSession canAddOutput:pipeline.dataOutput]) {
        [(AVCaptureAudioDataOutput *)pipeline.dataOutput setSampleBufferDelegate:self queue:pipeline.queue];
        [self.captureSession addOutputWithNoConnections:pipeline.dataOutput];
    } else {
        NSLog(@"不能添加 %@ 输出", pipeline.device.class);
        return;
    }
    if ([self.captureSession canAddConnection:pipeline.connection]) {
        [self.captureSession addConnection:pipeline.connection];
    } else {
        NSLog(@"不能添加 %@ 连接", pipeline.device.class);
        return;
    }
}

//- (void)addOutputSynchronizer {
//    NSMutableArray<AVCaptureOutput *> *outputsArray = [NSMutableArray array];
//    [self.videoPipelinesArray enumerateObjectsUsingBlock:^(HZVideoCapturePipeline * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        [outputsArray addObject:obj.dataOutput];
//    }];
//    if (outputsArray.count <= 0) {
//        NSLog(@"没有设备，不需要添加 AVCaptureDataOutputSynchronizer");
//        return;
//    }
//    self.dataOutputSynchronizer = [[AVCaptureDataOutputSynchronizer alloc] initWithDataOutputs:outputsArray];
//    [self.dataOutputSynchronizer setDelegate:self queue:self.videoPipelinesArray[0].queue];
//}

- (void)startCapture {
    dispatch_async(self.queue, ^{
        AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (videoAuthStatus != AVAuthorizationStatusAuthorized) {
            NSLog(@"没有视频权限");
            return;
        }
        
        if (self.captureSession.isRunning) {
            NSLog(@"正在采集");
            return;
        }
        
        if (self.captureSession.inputs.count > 0) {
            [self.captureSession startRunning];
            return;
        }
        
        [self.captureSession beginConfiguration];
        do {
            if (self.videoPipelinesArray.count <= 0) {
                NSLog(@"没有视频设备");
                break;
            }
            [self.videoPipelinesArray enumerateObjectsUsingBlock:^(HZVideoCapturePipeline * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self addPipeline:obj];
            }];
            //[self addOutputSynchronizer];
        } while (NO);
        
        do {
            if (!self.audioPipeline) {
                NSLog(@"未添加音频设备");
                break;
            }
            [self addPipeline:self.audioPipeline];
        } while (NO);
        [self.captureSession commitConfiguration];
        
        [self.captureSession startRunning];
    });
}

- (void)stopCapture {
    dispatch_async(self.queue, ^{
        if (!self.captureSession.isRunning) {
            NSLog(@"没有在采集");
            return;
        }
        
        [self.captureSession stopRunning];
    });
}

- (BOOL)adjustFrameRate:(int32_t)frameRate {
//    NSError *error = nil;
//    AVFrameRateRange *frameRateRange = [self.videoInput.device.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0];
//    if (frameRate > frameRateRange.maxFrameRate || frameRate < frameRateRange.minFrameRate) {
//        NSLog(@"当前帧率不支持");
//        return NO;
//    }
//
//    if ([self.videoInput.device lockForConfiguration:&error]) {
//        self.videoInput.device.activeVideoMinFrameDuration = CMTimeMake(1, frameRate);
//        self.videoInput.device.activeVideoMaxFrameDuration = CMTimeMake(1, frameRate);
//        [self.videoInput.device unlockForConfiguration];
//        return YES;
//    }
    return NO;
}

//- (void)imageCapture:(void(^)(UIImage *image))completion {
//    // 根据连接取得设备输出的数据
//        [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:self.captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
//            if (imageDataSampleBuffer && completion) {
//                UIImage *image = [UIImage imageWithData:[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer]];
//                completion(image);
//            }
//        }];
//}


- (void)switchVideoToDevices:(nullable NSArray<AVCaptureDevice *> *)videoDevicesArray {
    dispatch_async(self.queue, ^{
        AVCaptureDevice *device = nil;
        if (videoDevicesArray.count <= 0) {
            AVCaptureDevicePosition currentPosition = AVCaptureDevicePositionFront;
            AVCaptureDevicePosition toPosition = AVCaptureDevicePositionBack;
            if (self.videoPipelinesArray.count > 0) {
                currentPosition = self.videoPipelinesArray[0].device.position;
            }
            if (currentPosition == AVCaptureDevicePositionBack || currentPosition == AVCaptureDevicePositionUnspecified) {
                toPosition = AVCaptureDevicePositionFront;
            } else {
                toPosition = AVCaptureDevicePositionBack;
            }
            device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:toPosition];
            if (!device) {
                NSLog(@"switchToVideoDevice 没找到合适设备");
                return;
            }
        }
        // 修改输入设备
        [self.captureSession beginConfiguration];
        [self.videoPipelinesArray enumerateObjectsUsingBlock:^(HZVideoCapturePipeline * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.captureSession removeInput:obj.input];
            [self.captureSession removeOutput:obj.dataOutput];
            //[self.captureSession removeConnection:obj.connection];
        }];
        [self.videoPipelinesArray removeAllObjects];
        [videoDevicesArray enumerateObjectsUsingBlock:^(AVCaptureDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            HZVideoCapturePipeline *videoCapturePipeline = [[HZVideoCapturePipeline alloc] initWithDevice:obj];
            [self addPipeline:videoCapturePipeline];
            [self.videoPipelinesArray addObject:videoCapturePipeline];
        }];
        //[self addOutputSynchronizer];
        [self.captureSession commitConfiguration];
    });
}

/** 采集过程中动态修改视频分辨率 */
- (void)changeSessionPreset:(AVCaptureSessionPreset)sessionPreset {
    [self.captureSession beginConfiguration];
    if ([self.captureSession canSetSessionPreset:sessionPreset]) {
        self.captureSession.sessionPreset = sessionPreset;
    } else {
        NSLog(@"不能设置 AVCaptureSessionPreset");
    }
    [self.captureSession commitConfiguration];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([output isKindOfClass:[AVCaptureVideoDataOutput class]]) {
        //CVImageBufferRef pixelBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        //CGFloat frameWidth = CVPixelBufferGetWidth(pixelBuffer);
        //CGFloat frameHeight = CVPixelBufferGetHeight(pixelBuffer);
        //NSLog(@"frameWidth %lf, frameHeight %lf", frameWidth, frameHeight);
        //NSLog(@"视频");
        if ([self.delegate respondsToSelector:@selector(capture:didOutputVideoSampleBuffer:fromDevice:)]) {
            __block AVCaptureDevice *device = nil;
            [self.videoPipelinesArray enumerateObjectsUsingBlock:^(HZVideoCapturePipeline * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.dataOutput == output) {
                    device = obj.device;
                    *stop = YES;
                }
            }];
            //CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            //Float64 seconds = CMTimeGetSeconds(time);
            //NSLog(@"%@ %f", device.localizedName, seconds);
            [self.delegate capture:self didOutputVideoSampleBuffer:sampleBuffer fromDevice:device];
        }
    } else if ([output isKindOfClass:[AVCaptureAudioDataOutput class]]) {
        //NSLog(@"音频");
        if ([self.delegate respondsToSelector:@selector(capture:didOutputAudioSampleBuffer:)]) {
            [self.delegate capture:self didOutputAudioSampleBuffer:sampleBuffer];
        }
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([output isKindOfClass:[AVCaptureVideoDataOutput class]]) {
        NSLog(@"视频 掉帧");
    } else if ([output isKindOfClass:[AVCaptureAudioDataOutput class]]) {
        NSLog(@"音频 掉帧");
    }
}

//#pragma mark - AVCaptureDataOutputSynchronizerDelegate
//- (void)dataOutputSynchronizer:(AVCaptureDataOutputSynchronizer *)synchronizer didOutputSynchronizedDataCollection:(AVCaptureSynchronizedDataCollection *)synchronizedDataCollection {
//    [self.videoPipelinesArray enumerateObjectsUsingBlock:^(HZVideoCapturePipeline * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        AVCaptureSynchronizedSampleBufferData *synchronizedData = (AVCaptureSynchronizedSampleBufferData *)[synchronizedDataCollection synchronizedDataForCaptureOutput:obj.dataOutput];
//        CMSampleBufferRef sampleBuffer = synchronizedData.sampleBuffer;
//        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//        if (synchronizedData.sampleBufferWasDropped) {
//            NSLog(@"sampleBufferWasDropped %@", sampleBuffer);
//        }
//        if ([self.delegate respondsToSelector:@selector(capture:didOutputVideoSampleBuffer:fromDevice:)]) {
//            [self.delegate capture:self didOutputVideoSampleBuffer:sampleBuffer fromDevice:obj.device];
//        }
//    }];
//    
//    //NSLog(@"%lu", (unsigned long)synchronizedDataCollection.count);
//}

@end
