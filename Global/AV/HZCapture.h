//
//  HZCapture.h
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/18.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HZCapture;

@protocol HZCapturerDelegate <NSObject>
@optional
- (void)capture:(HZCapture *)capture didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer fromDevice:(AVCaptureDevice *)device;
- (void)capture:(HZCapture *)capture didOutputAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end


@interface HZCapture : NSObject

@property (nonatomic, weak) id<HZCapturerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL usingMultiCamera;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/*!
 @method    devicesWithDeviceType:position:
 @abstract  获取设备，可以是视频设备，也可以是音频设备
 @param deviceType
 设备类型，下面是AVCaptureDevice.h头文件注释的翻译：
 AVCaptureDeviceTypeBuiltInWideAngleCamera 一个内置的广角摄像头设备。这些设备适用于一般用途。
 AVCaptureDeviceTypeBuiltInTelephotoCamera 一个内置的具有比广角摄像头更长焦距的摄像头设备。请注意，只有使用 AVCaptureDeviceDiscoverySession 才能发现此类型的设备。
 AVCaptureDeviceTypeBuiltInUltraWideCamera 一个内置的具有比广角摄像头更短焦距的摄像头设备。请注意，只有使用 AVCaptureDeviceDiscoverySession 才能发现此类型的设备。
 AVCaptureDeviceTypeBuiltInDualCamera 一个设备，由两个固定焦距的摄像头组成，一个广角和一个望远。请注意，只有使用 AVCaptureDeviceDiscoverySession 或 -[AVCaptureDevice defaultDeviceWithDeviceType:mediaType:position:] 才能发现此类型的设备。
 此类型的设备支持以下功能：
     - 当变焦因素、光照水平和对焦位置允许时，自动从一个摄像头切换到另一个摄像头。
     - 通过合并两个摄像头的图像，为静态捕获提供更高质量的变焦。
     - 通过测量广角和望远摄像头之间匹配特征的视差来提供深度数据。
     - 通过单个照片捕获请求，从组成设备（广角和望远摄像头）交付照片。
 此类型的设备不支持以下功能：
     - AVCaptureExposureModeCustom 和手动曝光分段。
     - 使用与 AVCaptureLensPositionCurrent 不同的镜头位置锁定对焦。
     - 使用与 AVCaptureWhiteBalanceGainsCurrent 不同的设备白平衡增益锁定自动白平衡。
 即使在锁定状态下，当设备从一个摄像头切换到另一个摄像头时，曝光时间、ISO、光圈、白平衡增益或镜头位置也可能发生变化。但总体曝光、白平衡和对焦位置应保持一致。
 AVCaptureDeviceTypeBuiltInDualWideCamera 一个设备，由两个固定焦距的摄像头组成，一个超广角和一个广角。请注意，只有使用 AVCaptureDeviceDiscoverySession 或 -[AVCaptureDevice defaultDeviceWithDeviceType:mediaType:position:] 才能发现此类型的设备。
 此类型的设备支持以下功能：
     - 当变焦因素、光照水平和对焦位置允许时，自动从一个摄像头切换到另一个摄像头。
     - 通过测量超广角和广角摄像头之间匹配特征的视差来提供深度数据。
     - 通过单个照片捕获请求，从组成设备（超广角和广角）交付照片。
 此类型的设备不支持以下功能：
     - AVCaptureExposureModeCustom 和手动曝光分段。
     - 使用与 AVCaptureLensPositionCurrent 不同的镜头位置锁定对焦。
     - 使用与 AVCaptureWhiteBalanceGainsCurrent 不同的设备白平衡增益锁定自动白平衡。
 即使在锁定状态下，当设备从一个摄像头切换到另一个摄像头时，曝光时间、ISO、光圈、白平衡增益或镜头位置也可能发生变化。但总体曝光、白平衡和对焦位置应保持一致。
 AVCaptureDeviceTypeBuiltInTripleCamera 一个设备，由三个固定焦距的摄像头组成，一个超广角、一个广角和一个望远。请注意，只有使用 AVCaptureDeviceDiscoverySession 或 -[AVCaptureDevice defaultDeviceWithDeviceType:mediaType:position:] 才能发现此类型的设备。
 此类型的设备支持以下功能：
     - 当变焦因素、光照水平和对焦位置允许时，自动从一个摄像头切换到另一个摄像头。
     - 通过单个照片捕获请求，从组成设备（超广角、广角和望远摄像头）交付照片。
 此类型的设备不支持以下功能：
     - AVCaptureExposureModeCustom 和手动曝光分段。
     - 使用与 AVCaptureLensPositionCurrent 不同的镜头位置锁定对焦。
     - 使用与 AVCaptureWhiteBalanceGainsCurrent 不同的设备白平衡增益锁定自动白平衡。
 即使在锁定状态下，当设备从一个摄像头切换到另一个摄像头时，曝光时间、ISO、光圈、白平衡增益或镜头位置也可能发生变化。但总体曝光、白平衡和对焦位置应保持一致。
 AVCaptureDeviceTypeBuiltInTrueDepthCamera 一个设备，由两个摄像头组成，一个YUV摄像头和一个红外摄像头。 红外摄像头提供高质量的深度信息，该信息与YUV摄像头生成的帧同步且透视校正。虽然深度数据和YUV帧的分辨率可能不同，但它们的视场和纵横比始终匹配。请注意，只有使用 AVCaptureDeviceDiscoverySession 或 -[AVCaptureDevice defaultDeviceWithDeviceType:mediaType:position:] 才能发现此类型的设备。
 AVCaptureDeviceTypeBuiltInLiDARDepthCamera 一个设备，由两个摄像头组成，一个YUV摄像头和一个激光雷达（LiDAR）。 激光雷达摄像头通过测量激光发射的人工光信号的往返时间，提供高质量、高精度的深度信息。深度数据与YUV摄像头生成的帧同步且透视校正。虽然深度数据和YUV帧的分辨率可能不同，但它们的视场和纵横比始终匹配。请注意，只有使用 AVCaptureDeviceDiscoverySession 或 -[AVCaptureDevice defaultDeviceWithDeviceType:mediaType:position:] 才能发现此类型的设备。
 AVCaptureDeviceTypeDeskViewCamera 一个经过畸变校正的超广角摄像头，设计成近似于指向桌面的顶视摄像头。支持多摄像头操作。
 AVCaptureDeviceTypeBuiltInDuoCamera AVCaptureDeviceTypeBuiltInDualCamera 的已弃用的同义词。请改用 AVCaptureDeviceTypeBuiltInDualCamera。

 @param mediaType
            设备的媒体类型
 @param position
            设备的位置，音频使用 AVCaptureDevicePositionUnspecified
 @result        获取到的设备
 @discussion    先用此方法获取设备，再初始化HZCapture
 */
+ (NSArray<AVCaptureDevice *> *)devicesWithDeviceType:(AVCaptureDeviceType)deviceType mediaType:(AVMediaType)mediaType position:(AVCaptureDevicePosition)position;

#if TARGET_OS_IPHONE
/// iOS支持多个摄像头
- (instancetype)initWithDelegate:(nullable id<HZCapturerDelegate>)delegate videoDevices:(nullable NSArray<AVCaptureDevice *> *)videoDevicesArray audioDevice:(nullable AVCaptureDevice *)audioDevice needsMultiCamera:(BOOL)needsMultiCamera;
#elif TARGET_OS_OSX
/// Mac只支持一个摄像头
- (instancetype)initWithDelegate:(nullable id<HZCapturerDelegate>)delegate videoDevice:(nullable AVCaptureDevice *)videoDevice audioDevice:(nullable AVCaptureDevice *)audioDevice;
#endif
/// 不支持多摄像头
- (instancetype)initWithDefaultVideoDeviceAndAudioDeviceAndDelegate:(nullable id<HZCapturerDelegate>)delegate;
/// 不支持多摄像头
- (instancetype)initWithDefaultVideoDeviceAndDelegate:(nullable id<HZCapturerDelegate>)delegate;
- (instancetype)initWithDefaultAudioDeviceAndDelegate:(nullable id<HZCapturerDelegate>)delegate;
- (void)startCapture;
- (void)stopCapture;
//- (void)imageCapture:(void(^)(UIImage *image))completion;
- (BOOL)adjustFrameRate:(int32_t)frameRate;
/**!
 @method    switchVideoToDevices:
 @abstract  切换摄像头
 @param videoDevicesArray
        要切换的摄像头设备，传nil或空数组时切换前后摄像头
 */
- (void)switchVideoToDevices:(nullable NSArray<AVCaptureDevice *> *)videoDevicesArray;
- (void)changeSessionPreset:(AVCaptureSessionPreset)sessionPreset;

@end

NS_ASSUME_NONNULL_END
