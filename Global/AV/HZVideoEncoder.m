//
//  HZVideoEncoder.m
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/23.
//

#import "HZVideoEncoder.h"


@interface HZVideoEncoder ()

@property (assign, nonatomic) VTCompressionSessionRef compressionSessionRef;

@end

static void c_encodeOutputDataCallback(void * CM_NULLABLE outputCallbackRefCon,
                                       void * CM_NULLABLE sourceFrameRefCon, OSStatus status,
                                       VTEncodeInfoFlags infoFlags,
                                       CM_NULLABLE CMSampleBufferRef sampleBuffer) {
    if (noErr != status || nil == sampleBuffer) {
        NSLog(@"VEVideoEncoder::encodeOutputCallback Error : %d %p", status, sampleBuffer);
        return;
    }
    
    if (nil == outputCallbackRefCon) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    if (infoFlags & kVTEncodeInfo_FrameDropped) {
        NSLog(@"VEVideoEncoder::H264 encode dropped frame.");
        return;
    }
    
    HZVideoEncoder *encoder = (__bridge HZVideoEncoder *)outputCallbackRefCon;
    if (!encoder.delegate) {
        NSLog(@"encoder.delegate is nil");
        return;
    }
    const char header[] = "\x00\x00\x00\x01";
    size_t headerLen = (sizeof header) - 1;
    NSData *headerData = [NSData dataWithBytes:header length:headerLen];
    
    BOOL isKeyFrame = NO;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if(attachments != NULL) {
        CFDictionaryRef attachment =(CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFBooleanRef dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyFrame = (dependsOnOthers == kCFBooleanFalse);
    }
    
    if (isKeyFrame) {
        // NSLog(@"VEVideoEncoder::编码了一个关键帧");
        if ([encoder.delegate respondsToSelector:@selector(videoEncodeDidOutputVpsData:spsData:ppsDataData:ppsExtesionData:codecType:)]) {
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
            if (encoder.videoCodecType == kCMVideoCodecType_H264) {
                size_t sParameterSetSize, sParameterSetCount;
                const uint8_t *sParameterSet;
                OSStatus spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, 0, &sParameterSet, &sParameterSetSize, &sParameterSetCount, NULL);
                size_t pParameterSetSize, pParameterSetCount;
                const uint8_t *pParameterSet;
                OSStatus ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, 1, &pParameterSet, &pParameterSetSize, &pParameterSetCount, NULL);
                if (noErr == spsStatus && noErr == ppsStatus) {
                    NSData *sps = [NSData dataWithBytes:sParameterSet length:sParameterSetSize];
                    NSData *pps = [NSData dataWithBytes:pParameterSet length:pParameterSetSize];
                    NSMutableData *spsData = [NSMutableData data];
                    [spsData appendData:headerData];
                    [spsData appendData:sps];
                    NSMutableData *ppsData = [NSMutableData data];
                    [ppsData appendData:headerData];
                    [ppsData appendData:pps];
                    [encoder.delegate videoEncodeDidOutputVpsData:nil spsData:spsData ppsDataData:ppsData ppsExtesionData:nil codecType:kCMVideoCodecType_H264];
                }
            } else if (encoder.videoCodecType == kCMVideoCodecType_HEVC) {
                size_t vParameterSetSize, parameterSetCount;
                const uint8_t *vParameterSet;
                OSStatus vpsStatus = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription, 0, &vParameterSet, &vParameterSetSize, &parameterSetCount, NULL);
                size_t sParameterSetSize;
                const uint8_t *sParameterSet;
                OSStatus spsStatus = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription, 1, &sParameterSet, &sParameterSetSize, NULL, NULL);
                size_t pParameterSetSize;
                const uint8_t *pParameterSet;
                OSStatus ppsStatus = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription, 2, &pParameterSet, &pParameterSetSize, NULL, NULL);
                if (noErr == vpsStatus && noErr == spsStatus && noErr == ppsStatus) {
                    NSData *vps = [NSData dataWithBytes:vParameterSet length:vParameterSetSize];
                    NSMutableData *vpsData = [NSMutableData data];
                    [vpsData appendData:headerData];
                    [vpsData appendData:vps];
                    NSData *sps = [NSData dataWithBytes:sParameterSet length:sParameterSetSize];
                    NSMutableData *spsData = [NSMutableData data];
                    [spsData appendData:headerData];
                    [spsData appendData:sps];
                    NSData *pps = [NSData dataWithBytes:pParameterSet length:pParameterSetSize];
                    NSMutableData *ppsData = [NSMutableData data];
                    [ppsData appendData:headerData];
                    [ppsData appendData:pps];
                    NSMutableData *ppsExtentionData = nil;
                    if (parameterSetCount > 3) {
                        size_t pParameterExtentionSetSize;
                        const uint8_t *pParameterExtentionSet;
                        OSStatus ppsExtentionStatus = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription, 3, &pParameterExtentionSet, &pParameterExtentionSetSize, NULL, NULL);
                        if (noErr == ppsExtentionStatus) {
                            NSData *ppsExtention = [NSData dataWithBytes:pParameterExtentionSet length:pParameterExtentionSetSize];
                            ppsExtentionData = [NSMutableData data];
                            [ppsExtentionData appendData:headerData];
                            [ppsExtentionData appendData:ppsExtention];
                        }
                    }
                    [encoder.delegate videoEncodeDidOutputVpsData:vpsData spsData:spsData ppsDataData:ppsData ppsExtesionData:ppsExtentionData codecType:kCMVideoCodecType_HEVC];
                }
            }
        }
    }
    
    if ([encoder.delegate respondsToSelector:@selector(videoEncodeDidOutputData:isKeyFrame:presentationTimeStamp:codecType:)]) {
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t length, totalLength;
        char *dataPointer;
        status = CMBlockBufferGetDataPointer(blockBuffer, 0, &length, &totalLength, &dataPointer);
        if (noErr != status) {
            NSLog(@"VEVideoEncoder::CMBlockBufferGetDataPointer Error : %d!", (int)status);
            return;
        }
        
        size_t bufferOffset = 0;
        static const int avcHeaderLength = 4;
        while (bufferOffset < totalLength - avcHeaderLength) {
            // 读取 NAL 单元长度
            uint32_t nalUnitLength = 0;
            memcpy(&nalUnitLength, dataPointer + bufferOffset, avcHeaderLength);
            
            // 大端转小端
            nalUnitLength = CFSwapInt32BigToHost(nalUnitLength);
            
            NSData *frameData = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + avcHeaderLength) length:nalUnitLength];
            
            NSMutableData *outputFrameData = [NSMutableData data];
            [outputFrameData appendData:headerData];
            [outputFrameData appendData:frameData];
            
            //if (bufferOffset != 0) {
            //    NSLog(@"一次编码里有多组数据");
            //}
            bufferOffset += avcHeaderLength + nalUnitLength;
            //NSLog(@"frame: %@", frameData);
            CMTime ptsTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            Float64 presentationTimeStamp = CMTimeGetSeconds(ptsTime);
            //NSLog(@"pts: %f", presentationTimeStamp);
            [encoder.delegate videoEncodeDidOutputData:outputFrameData isKeyFrame:isKeyFrame presentationTimeStamp:presentationTimeStamp codecType:encoder.videoCodecType];
        }
    }
}

@implementation HZVideoEncoder

- (void)dealloc {
    NSLog(@"%s", __func__);
    if (self.compressionSessionRef) {
        VTCompressionSessionCompleteFrames(self.compressionSessionRef, kCMTimeInvalid);
        VTCompressionSessionInvalidate(self.compressionSessionRef);
        CFRelease(self.compressionSessionRef);
        self.compressionSessionRef = NULL;
    }
}

- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType delegate:(id<HZVideoEncoderDelegate>)delegate {
    if (self = [super init]) {
        _videoCodecType = videoCodecType;
        self.delegate = delegate;
    }
    return self;
}

- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType {
    return [self initWithVideoCodecType:videoCodecType delegate:nil];
}

- (void)prepareEncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMVideoFormatDescriptionRef videoFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(videoFormatDescription);
    OSStatus status = VTCompressionSessionCreate(NULL, dimension.width, dimension.height, self.videoCodecType, NULL, NULL, NULL, c_encodeOutputDataCallback, (__bridge void *)(self), &_compressionSessionRef);
    if (noErr != status) {
        NSLog(@"VTCompressionSessionCreate: %d", (int)status);
        return;
    }
    if (!self.compressionSessionRef) {
        NSLog(@"compressionSessionRef 创建出错");
        return;
    }
    
    int32_t bitRate = dimension.width * dimension.height * 3;
    VTSessionSetProperty(self.compressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bitRate));
    if (noErr != status) {
        NSLog(@"VTSessionSetProperty AverageBitRate: %d", (int)status);
        return;
    }
    // 参考webRTC 限制最大码率不超过平均码率的1.5倍
    int64_t dataLimitBytesPerSecondValue = bitRate * 1.5 / 8;
    CFNumberRef bytesPerSecond = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &dataLimitBytesPerSecondValue);
    int64_t oneSecondValue = 1;
    CFNumberRef oneSecond = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &oneSecondValue);
    const void* nums[2] = {bytesPerSecond, oneSecond};
    CFArrayRef dataRateLimits = CFArrayCreate(NULL, nums, 2, &kCFTypeArrayCallBacks);
    status = VTSessionSetProperty(self.compressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, dataRateLimits);
    if (noErr != status) {
        NSLog(@"VTSessionSetProperty DataRateLimits: %d", (int)status);
        return;
    }
    
    // ProfileLevel，h264的协议等级，不同的清晰度使用不同的ProfileLevel。
    CFStringRef profileRef = kVTProfileLevel_H264_High_5_2;
    if (self.videoCodecType == kCMVideoCodecType_H264) {
        profileRef = kVTProfileLevel_H264_High_5_2;
    } else if (self.videoCodecType == kCMVideoCodecType_HEVC) {
        profileRef = kVTProfileLevel_HEVC_Main10_AutoLevel;
    }
    status = VTSessionSetProperty(self.compressionSessionRef, kVTCompressionPropertyKey_ProfileLevel, profileRef);
    CFRelease(profileRef);
    if (noErr != status) {
        NSLog(@"VTSessionSetProperty ProfileLevel: %d", (int)status);
    }
    
    // 设置实时编码输出（避免延迟）
    status = VTSessionSetProperty(self.compressionSessionRef, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    if (noErr != status) {
        NSLog(@"VTSessionSetProperty RealTime: %d", (int)status);
    }
    
    // 配置是否产生B帧
    status = VTSessionSetProperty(self.compressionSessionRef, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    if (noErr != status) {
        NSLog(@"VTSessionSetProperty AllowFrameReordering: %d", (int)status);
    }
    
    // 配置I帧间隔
    long maxKeyFrameIntervallDuration = 2;
    //long maxKeyFrameInterval = 15 * maxKeyFrameIntervallDuration;
    //status = VTSessionSetProperty(self.compressionSessionRef,
    //                              kVTCompressionPropertyKey_MaxKeyFrameInterval,
    //                              (__bridge CFTypeRef)@(maxKeyFrameInterval));
    //if (noErr != status) {
    //    NSLog(@"VTSessionSetProperty MaxKeyFrameInterval: %d", (int)status);
    //}
    status = VTSessionSetProperty(self.compressionSessionRef,
                                  kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
                                  (__bridge CFTypeRef)@(maxKeyFrameIntervallDuration));
    if (noErr != status) {
        NSLog(@"VTSessionSetProperty MaxKeyFrameIntervalDuration: %d", (int)status);
    }
    
    // 编码器准备编码
    status = VTCompressionSessionPrepareToEncodeFrames(self.compressionSessionRef);
    if (noErr != status) {
        NSLog(@"VTCompressionSessionPrepareToEncodeFrames: %d", (int)status);
    }
    
    //kVTCompressionPropertyKey_H264EntropyMode;kVTH264EntropyMode_CAVLC;
}

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer forceKeyFrame:(BOOL)forceKeyFrame {
    if (!sampleBuffer) {
        return;
    }
    
    if (!self.compressionSessionRef) {
        [self prepareEncodeWithSampleBuffer:sampleBuffer];
    }
    
    CVImageBufferRef pixelBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    //size_t width = CVPixelBufferGetWidth(pixelBuffer);
    //size_t height = CVPixelBufferGetHeight(pixelBuffer);
    //NSLog(@"%zu %zu", width, height);
    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
    NSDictionary *frameProperties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @(forceKeyFrame)};
    OSStatus status = VTCompressionSessionEncodeFrame(self.compressionSessionRef, pixelBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)frameProperties, NULL, NULL);
    if (noErr != status) {
        NSLog(@"VEVideoEncoder::VTCompressionSessionEncodeFrame failed! status:%d", (int)status);
    }
}

@end
