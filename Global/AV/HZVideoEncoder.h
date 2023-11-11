//
//  HZVideoEncoder.h
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/23.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol HZVideoEncoderDelegate <NSObject>

@optional
- (void)videoEncodeDidOutputVpsData:(nullable NSData *)vpsData spsData:(nonnull NSData *)spsData ppsDataData:(nonnull NSData *)ppsData ppsExtesionData:(nullable NSData *)ppsExtesionData codecType:(CMVideoCodecType)codecType;
- (void)videoEncodeDidOutputData:(nonnull NSData *)data isKeyFrame:(BOOL)isKeyFrame presentationTimeStamp:(Float64)presentationTimeStamp codecType:(CMVideoCodecType)codecType;

@end


@interface HZVideoEncoder : NSObject

@property (nonatomic, weak) id<HZVideoEncoderDelegate> delegate;
@property (nonatomic, assign, readonly) CMVideoCodecType videoCodecType;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 用编码类型初始化编码器，支持kCMVideoCodecType_H264和kCMVideoCodecType_HEVC
/// - Parameter videoCodecType: 支持h264和h265
- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType delegate:(nullable id<HZVideoEncoderDelegate>)delegate;
- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType;
- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer forceKeyFrame:(BOOL)forceKeyFrame;

@end

NS_ASSUME_NONNULL_END
