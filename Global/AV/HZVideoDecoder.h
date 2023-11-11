//
//  HZVideoDecoder.h
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/24.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class HZVideoDecoder;
@protocol HZVideoDecoderDelegate <NSObject>

@optional
- (void)videoDecoder:(HZVideoDecoder *)videoDecoder didOutputImageBuffer:(CVPixelBufferRef)imageBuffer presentationTimeStamp:(CMTime)presentationTimeStamp;

@end


@interface HZVideoDecoder : NSObject

@property (weak, nonatomic) id<HZVideoDecoderDelegate> delegate;
@property (nonatomic, assign, readonly) CMVideoCodecType videoCodecType;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 用编码类型初始化解码器，支持h264和h265
/// - Parameter videoCodecType: 支持h264和h265
/// - Parameter delegate: 代理回调
- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType delegate:(nullable id<HZVideoDecoderDelegate>)delegate;
- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType;

- (void)decodeNaluData:(NSData *)naluData presentationTimeStamp:(Float64)presentationTimeStamp;

@end

NS_ASSUME_NONNULL_END
