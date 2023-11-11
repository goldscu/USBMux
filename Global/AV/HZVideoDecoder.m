//
//  HZVideoDecoder.m
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/24.
//

#import "HZVideoDecoder.h"

@interface HZVideoDecoder ()

@property (nonatomic, assign) uint8_t *vps;
@property (nonatomic, assign) NSInteger vpsSize;
@property (nonatomic, assign) uint8_t *sps;
@property (nonatomic, assign) NSInteger spsSize;
@property (nonatomic, assign) uint8_t *pps;
@property (nonatomic, assign) NSInteger ppsSize;
@property (nonatomic, assign) uint8_t *ppsExtent;
@property (nonatomic, assign) NSInteger ppsExtentSize;
@property (nonatomic, assign) VTDecompressionSessionRef decoderSession;
@property (nonatomic, assign) CMVideoFormatDescriptionRef decoderFormatDescription;

@end

@implementation HZVideoDecoder

//解码回调函数
static void c_decodeOutputDataCallback(void *decompressionOutputRefCon,
                                       void *sourceFrameRefCon,
                                       OSStatus status,
                                       VTDecodeInfoFlags infoFlags,
                                       CVImageBufferRef pixelBuffer,
                                       CMTime presentationTimeStamp,
                                       CMTime presentationDuration) {
    if (!pixelBuffer) {
        return;
    }
    //CMTimeShow(presentationTimeStamp);
    // retain再输出，外层去release
    CVPixelBufferRetain(pixelBuffer);
    //size_t width = CVPixelBufferGetWidth(pixelBuffer);
    //size_t height = CVPixelBufferGetHeight(pixelBuffer);
    //NSLog(@"%zu %zu", width, height);
    HZVideoDecoder *decoder = (__bridge HZVideoDecoder *)decompressionOutputRefCon;
    if ([decoder.delegate respondsToSelector:@selector(videoDecoder:didOutputImageBuffer:presentationTimeStamp:)]) {
        [decoder.delegate videoDecoder:decoder didOutputImageBuffer:pixelBuffer presentationTimeStamp:presentationTimeStamp];
    }
    //CVPixelBufferRelease(pixelBuffer);
}

- (void)dealloc {
    if (self.vps) {
        free(self.vps);
        self.vps = NULL;
    }
    if (self.sps) {
        free(self.sps);
        self.sps = NULL;
    }
    if (self.pps) {
        free(self.pps);
        self.pps = NULL;
    }
    
    if (self.decoderSession) {
        VTDecompressionSessionWaitForAsynchronousFrames(self.decoderSession);
        VTDecompressionSessionInvalidate(self.decoderSession);
        CFRelease(self.decoderSession);
        self.decoderSession = NULL;
    }
}

- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType delegate:(nullable id<HZVideoDecoderDelegate>)delegate {
    if (self = [super init]) {
        _videoCodecType = videoCodecType;
        self.delegate = delegate;
    }
    return self;
}

- (instancetype)initWithVideoCodecType:(CMVideoCodecType)videoCodecType {
    return [self initWithVideoCodecType:videoCodecType delegate:nil];
}

- (BOOL)prepareDecoder {
    if(self.decoderSession) {
        return YES;
    }
    
    OSStatus status = noErr;
    if (self.videoCodecType == kCMVideoCodecType_H264) {
        if (!self.sps || !self.pps) {
            return NO;
        }
        
        const uint8_t* const parameterSetPointers[2] = {self.sps, self.pps};
        const size_t parameterSetSizes[2] = {self.spsSize, self.ppsSize};
        // 根据sps pps创建解码视频参数
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &_decoderFormatDescription);
        if(status != noErr) {
            NSLog(@"CreateFromH264ParameterSets %d", (int)status);
            return NO;
        }
    } else if (self.videoCodecType == kCMVideoCodecType_HEVC) {
        if (!self.vps || !self.sps || !self.pps) {
            return NO;
        }
        if (!self.ppsExtent) {
            const uint8_t *const parameterSetPointers[3] = {self.vps, self.sps, self.pps};
            const size_t parameterSetSizes[3] = {self.vpsSize, self.spsSize, self.ppsSize};
            status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault, 3, parameterSetPointers, parameterSetSizes, 4, NULL, &_decoderFormatDescription);
        } else {
            const uint8_t *const parameterSetPointers[4] = {self.vps, self.sps, self.pps, self.ppsExtent};
            const size_t parameterSetSizes[4] = {self.vpsSize, self.spsSize, self.ppsSize, self.ppsExtentSize};
            status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault, 4, parameterSetPointers, parameterSetSizes, 4, NULL, &_decoderFormatDescription);
        }
        if(status != noErr) {
            NSLog(@"CMVideoFormatDescriptionCreateFromHEVCParameterSets %d", (int)status);
            return NO;
        }
    }
    
    // 从sps pps中获取解码视频的宽高信息
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(self.decoderFormatDescription);
    
    // kCVPixelBufferPixelFormatTypeKey 解码图像的采样格式
    // kCVPixelBufferWidthKey、kCVPixelBufferHeightKey 解码图像的宽高
    // kCVPixelBufferOpenGLCompatibilityKey制定支持OpenGL渲染，经测试有没有这个参数好像没什么差别
    NSDictionary* destinationPixelBufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferWidthKey : @(dimensions.width),
        (id)kCVPixelBufferHeightKey : @(dimensions.height),
        //(id)kCVPixelBufferOpenGLCompatibilityKey : @(YES),
        //(id)kCVPixelBufferMetalCompatibilityKey : @(YES),
    };
    
    // 设置解码输出数据回调
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = c_decodeOutputDataCallback;
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    // 创建解码器
    status = VTDecompressionSessionCreate(kCFAllocatorDefault, self.decoderFormatDescription, NULL, (__bridge CFDictionaryRef)destinationPixelBufferAttributes, &callBackRecord, &_decoderSession);
    // 解码线程数量
    VTSessionSetProperty(self.decoderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)@(1));
    // 是否实时解码
    VTSessionSetProperty(self.decoderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    return YES;
}

- (void)decode:(uint8_t *)frame withSize:(uint32_t)frameSize presentationTimeStamp:(Float64)presentationTimeStamp {
    if(!self.decoderSession) {
        return;
    }
    
    CMBlockBufferRef blockBuffer = NULL;
    // 创建 CMBlockBufferRef
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(NULL, (void *)frame, frameSize, kCFAllocatorNull, NULL, 0, frameSize, FALSE, &blockBuffer);
    if(status != kCMBlockBufferNoErr) {
        return;
    }
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {frameSize};
    // 创建 CMSampleBufferRef
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, self.decoderFormatDescription , 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
    if (status != kCMBlockBufferNoErr || sampleBuffer == NULL) {
        return;
    }
    int32_t timescale = 1000000;
    int64_t value = timescale * presentationTimeStamp;
    CMTime outputPresentationTimeStamp = CMTimeMake(value, timescale);
    CMSampleBufferSetOutputPresentationTimeStamp(sampleBuffer, outputPresentationTimeStamp);
    // VTDecodeFrameFlags 0为允许多线程解码
    VTDecodeFrameFlags flags = 0;
    VTDecodeInfoFlags flagOut = 0;
    // 解码 这里第四个参数会传到解码的callback里的sourceFrameRefCon，可为空
    OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(self.decoderSession, sampleBuffer, flags, NULL, &flagOut);
    
    if(decodeStatus == kVTInvalidSessionErr) {
        NSLog(@"H264Decoder:: Invalid session");
    } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
        NSLog(@"H264Decoder:: Bad Data");
    } else if(decodeStatus != noErr) {
        NSLog(@"H264Decoder:: %d", (int)decodeStatus);
    }
    // Create了就得Release
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
    return;
}

- (void)decodeNaluData:(NSData *)naluData presentationTimeStamp:(Float64)presentationTimeStamp {
    uint8_t *frame = (uint8_t *)naluData.bytes;
    uint32_t frameSize = (uint32_t)naluData.length;
    
    // 将NALU的开始码替换成NALU的长度信息
    uint32_t nalSize = (uint32_t)(frameSize - 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    frame[0] = *(pNalSize + 3);
    frame[1] = *(pNalSize + 2);
    frame[2] = *(pNalSize + 1);
    frame[3] = *(pNalSize);
    
    if (self.videoCodecType == kCMVideoCodecType_H264) {
        // frame的前4位是NALU数据的开始码，也就是00 00 00 01，第5个字节是表示数据类型，转为10进制后，7是sps,8是pps,5是IDR（I帧）信息
        int nalu_type = (frame[4] & 0x1F);
        switch (nalu_type) {
            case 0x07: { // SPS
                // NSLog(@"NALU type is SPS frame %@", naluData);
                self.spsSize = frameSize - 4;
                if (self.sps) {
                    free(self.sps);
                    self.sps = NULL;
                }
                self.sps = malloc(self.spsSize);
                memcpy(self.sps, &frame[4], self.spsSize);
                
                break;
            }
                
            case 0x08: { // PPS
                //NSLog(@"NALU type is PPS frame %@", naluData);
                self.ppsSize = frameSize - 4;
                if (self.pps) {
                    free(self.pps);
                    self.pps = NULL;
                }
                self.pps = malloc(self.ppsSize);
                memcpy(self.pps, &frame[4], self.ppsSize);
                
                break;
            }
                
            default: {
                // 0x00：未使用的码流类型。
                // 0x01：非 IDR 图像的编码数据。
                // 0x02：仅用于片分区 A 类型的编码数据。
                // 0x03：仅用于片分区 B 类型的编码数据。
                // 0x04：仅用于片分区 C 类型的编码数据。
                // 0x05：IDR 图像的编码数据。
                // 0x06：SEI（Supplemental Enhancement Information）增强信息。
                // 0x07：SPS（Sequence Parameter Set）序列参数集。
                // 0x08：PPS（Picture Parameter Set）图像参数集。
                // 0x09：分界符。
                // 0x0A：序列结束。
                // 0x0B：码流结束。
                // 0x0C：填充。
                //NSLog(@"NALU type is B/P frame");
                if([self prepareDecoder]) {
                    [self decode:frame withSize:frameSize presentationTimeStamp:presentationTimeStamp];
                }
                
                break;
            }
        }
    } else if (self.videoCodecType == kCMVideoCodecType_HEVC) {
        uint16_t nalu_type = (frame[4] & 0x7E) >> 1;
        switch (nalu_type) {
            case 0x20: { // VPS
                //NSLog(@"NALU type is VPS %d", nalu_type);
                self.vpsSize = frameSize - 4;
                if (self.vps) {
                    free(self.vps);
                    self.vps = NULL;
                }
                self.vps = malloc(self.vpsSize);
                memcpy(self.vps, &frame[4], self.vpsSize);
                
                break;
            }
                
            case 0x21: { // SPS
                //NSLog(@"NALU type is SPS %d", nalu_type);
                self.spsSize = frameSize - 4;
                if (self.sps) {
                    free(self.sps);
                    self.sps = NULL;
                }
                self.sps = malloc(self.spsSize);
                memcpy(self.sps, &frame[4], self.spsSize);
                
                break;
            }
                
            case 0x22: { // PPS
                //NSLog(@"NALU type is PPS %d", nalu_type);
                self.ppsSize = frameSize - 4;
                if (self.pps) {
                    free(self.pps);
                    self.pps = NULL;
                }
                self.pps = malloc(self.ppsSize);
                memcpy(self.pps, &frame[4], self.ppsSize);
                
                break;
            }
                
//            case 0x22: { // PPS
//                NSLog(@"NALU type is PPS %d", nalu_type);
//                self.ppsExtentSize = frameSize - 4;
//                if (self.ppsExtent) {
//                    free(self.ppsExtent);
//                    self.ppsExtent = NULL;
//                }
//                self.ppsExtent = malloc(self.ppsExtentSize);
//                memcpy(self.ppsExtent, &frame[4], self.ppsExtentSize);
//                
//                break;
//            }
                
            default: {
                //NSLog(@"NALU type is I B P frame %d", nalu_type);
                if([self prepareDecoder]) {
                    [self decode:frame withSize:frameSize presentationTimeStamp:presentationTimeStamp];
                }
                
                break;
            }
        }
    }
}

@end
