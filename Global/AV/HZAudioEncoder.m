//
//  HZAudioEncoder.m
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/30.
//

#import "HZAudioEncoder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

static const UInt32 gHZEncodeFramesPerPacket = 1024;


@interface HZAudioEncoder ()

@property (nonatomic, unsafe_unretained) AudioConverterRef audioConverter;
@property (nonatomic, strong) dispatch_queue_t encoderQueue;
@property (nonatomic, strong) NSMutableData *allData;
@property (nonatomic, strong) NSData *encodeData;

@property (nonatomic, assign) AudioStreamBasicDescription inputStreamBasicDescription;
@property (nonatomic, assign) AudioStreamBasicDescription outputStreamBasicDescription;

@end

static OSStatus aacEncodeInputDataProc(AudioConverterRef inAudioConverter,
                                       UInt32 *ioNumberDataPackets,
                                       AudioBufferList *ioData,
                                       AudioStreamPacketDescription **outDataPacketDescription,
                                       void *inUserData) {
    HZAudioEncoder *aacEncoder = (__bridge HZAudioEncoder *)(inUserData);
//    if (aacEncoder.encodeData) {
        ioData->mBuffers[0].mData = (void *)aacEncoder.encodeData.bytes;
        ioData->mBuffers[0].mDataByteSize = (UInt32)aacEncoder.encodeData.length;
        //ioData->mBuffers[0].mNumberChannels = aacEncoder.outputStreamBasicDescription.mChannelsPerFrame;
        //ioData->mNumberBuffers = 1;
        //NSLog(@"input: %zu", aacEncoder.encodeData.length);
        *ioNumberDataPackets = (UInt32)aacEncoder.encodeData.length / aacEncoder.inputStreamBasicDescription.mBytesPerPacket;
//        aacEncoder.encodeData = nil;
//    } else {
//        *ioNumberDataPackets = 0;
//        return -1;
//    }
    
    return noErr;
}

@implementation HZAudioEncoder
- (void)dealloc {
    if (_audioConverter) {
        AudioConverterDispose(_audioConverter);
        _audioConverter = NULL;
    }
}

- (instancetype)init {
    if (self = [super init]) {
        self.allData = [NSMutableData data];
        self.encoderQueue = dispatch_queue_create("aac hard encoder queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)prepareEncoderWithSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    _inputStreamBasicDescription = *CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    _outputStreamBasicDescription.mSampleRate = self.inputStreamBasicDescription.mSampleRate;   //采样率
    _outputStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;                //输出格式
    _outputStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC;              // 如果设为0 代表无损编码
    _outputStreamBasicDescription.mBytesPerPacket = 0;                             //压缩的时候设置0
    _outputStreamBasicDescription.mFramesPerPacket = gHZEncodeFramesPerPacket;        //每一个packet帧数 AAC-1024；
    _outputStreamBasicDescription.mBytesPerFrame = 0;                              //压缩的时候设置0
    _outputStreamBasicDescription.mChannelsPerFrame = self.inputStreamBasicDescription.mChannelsPerFrame; //输出声道数
    _outputStreamBasicDescription.mBitsPerChannel = 0;                             //数据帧中每个通道的采样位数。压缩的时候设置0
    _outputStreamBasicDescription.mReserved =  0;                                  //对其方式 0(8字节对齐)
    UInt32 outDesSize = sizeof(_outputStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &outDesSize, &_outputStreamBasicDescription);
    AudioClassDescription *audioClassDesc = [self getAudioCalssDescriptionWithType:_outputStreamBasicDescription.mFormatID];
    OSStatus status = AudioConverterNewSpecific(&_inputStreamBasicDescription, &_outputStreamBasicDescription, 1, audioClassDesc, &_audioConverter);
    if (status != noErr) {
        NSLog(@"AudioConverterNewSpecific %d", status);
        return;
    }
    
    NSLog(@"音频编码 输入参数：");
    printAudioStreamBasicDescription(self.inputStreamBasicDescription);
    NSLog(@"音频编码 输出参数：");
    printAudioStreamBasicDescription(self.outputStreamBasicDescription);
    
    UInt32 temp = kAudioConverterQuality_High;
    //编解码器的呈现质量
    status = AudioConverterSetProperty(self.audioConverter, kAudioConverterCodecQuality, sizeof(temp), &temp);
    if (status != noErr) {
        NSLog(@"AudioConverter SetProperty CodecQuality %d", status);
    }
    //设置比特率
    uint32_t audioBitrate = 96000;
    uint32_t audioBitrateSize = sizeof(audioBitrate);
    status = AudioConverterSetProperty(self.audioConverter, kAudioConverterEncodeBitRate, audioBitrateSize, &audioBitrate);
    if (status != noErr) {
        NSLog(@"AudioConverter SetProperty BitRate %d", status);
    }
    uint32_t aMaxOutput = 0;
    uint32_t aMaxOutputSize = sizeof(aMaxOutput);
    status = AudioConverterGetProperty(self.audioConverter, kAudioConverterPropertyMinimumOutputBufferSize, &aMaxOutputSize, &aMaxOutput);
    if (status != noErr) {
        NSLog(@"AudioConverter GetProperty MaximumOutputPacketSize %d", status);
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(audioEncoderDidUseInputStreamBasicDescription:outputStreamBasicDescription:)]) {
        [self.delegate audioEncoderDidUseInputStreamBasicDescription:self.inputStreamBasicDescription outputStreamBasicDescription:self.outputStreamBasicDescription];
    }
}

- (AudioClassDescription *)getAudioCalssDescriptionWithType:(AudioFormatID)type {
    static AudioClassDescription desc;
    UInt32 encoderSpecific = type;
    UInt32 size;
    OSStatus status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecific), &encoderSpecific, &size);
    if(status != noErr){
        NSLog(@"Error！：硬编码AAC get info 失败, status= %d", (int)status);
        return nil;
    }
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription description[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecific), &encoderSpecific, &size, &description);
    for (unsigned int i = 0; i < count; i++) {
        if (type == description[i].mSubType
#if TARGET_OS_IPHONE
            && kAppleSoftwareAudioCodecManufacturer == description[i].mManufacturer
#endif
            ) {
            desc = description[i];
            return &desc;
        }
    }
    return nil;
}

- (void)_encodeAudioSamepleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t blockBufferSize;
    char * blockBufferData;
    OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &blockBufferSize, &blockBufferData);
    if (status != kCMBlockBufferNoErr) {
        NSLog(@"CMBlockBufferGetDataPointer %d", (int)status);
        return;
    }
    //NSLog(@"CMSampleBufferRef %zu", blockBufferSize);
    [self.allData appendBytes:blockBufferData length:blockBufferSize];
    UInt32 oneSize = gHZEncodeFramesPerPacket * self.inputStreamBasicDescription.mBytesPerFrame;
    if (self.allData.length < oneSize) {
        //NSLog(@"数据不足");
        return;
    }
    while (self.allData.length >= oneSize) {
        self.encodeData = [self.allData subdataWithRange:NSMakeRange(0, oneSize)];
        [self.allData replaceBytesInRange:NSMakeRange(0, oneSize) withBytes:NULL length:0];
        //NSLog(@"剩 %zu", self.allData.length);
        
        uint8_t *pcmBuffer = malloc(oneSize);
        memset(pcmBuffer, 0, oneSize);
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = self.outputStreamBasicDescription.mChannelsPerFrame;
        outAudioBufferList.mBuffers[0].mDataByteSize = oneSize;
        outAudioBufferList.mBuffers[0].mData = pcmBuffer;
        UInt32 outputDataPacketSize = 1;
        status = AudioConverterFillComplexBuffer(self.audioConverter, aacEncodeInputDataProc, (__bridge void * _Nullable)(self), &outputDataPacketSize, &outAudioBufferList, NULL);
        if (status == noErr) {
            NSMutableData *fullData = [NSMutableData data];
            NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
            [fullData appendData:adtsHeader];
            [fullData appendData:rawAAC];
            //NSLog(@"output %zu", rawAAC.length);
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            if (self.delegate && [self.delegate respondsToSelector:@selector(audioEncoderDidOutputData:pts:)]) {
                [self.delegate audioEncoderDidOutputData:fullData pts:pts];
            }
        } else {
            NSLog(@"AudioConverterFillComplexBuffer %d", status);
        }
        
        free(pcmBuffer);
    }
}

- (void)encodeAudioSamepleBuffer:(CMSampleBufferRef)sampleBuffer {
    CFRetain(sampleBuffer);
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.encoderQueue, ^{
        if(!self.audioConverter) {
            [weakSelf prepareEncoderWithSampleBuffer:sampleBuffer];
        }
        [weakSelf _encodeAudioSamepleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

/// adts 结构体
typedef struct {
    /// 固定头信息
    unsigned int syncword : 12; ///< 帧同步标识一个帧的开始，固定为0xFFF
    unsigned int ID : 1; ///< MPEG 标示符。0表示MPEG-4，1表示MPEG-2，两个值ffplay都能播
    unsigned int layer : 2; ///< 固定为'00'
    unsigned int protection_absent : 1; ///< 标识是否进行误码校验。0表示有CRC校验，1表示没有CRC校验
    unsigned int profile : 2; ///< 标识使用哪个级别的AAC 0: AAC Main, 1:AAC LC (Low Complexity), 2:AAC SSR (Scalable Sample Rate), 3:AAC LTP (Long Term Prediction)
    unsigned int sampling_frequency_index : 4; ///< 标识采样率：0: 96000 Hz, 1: 88200 Hz, 2: 64000 Hz, 3: 48000 Hz, 4: 44100 Hz, 5: 32000 Hz, 6: 24000 Hz, 7: 22050 Hz, 8: 16000 Hz, 9: 12000 Hz, 10: 11025 Hz, 11: 8000 Hz, 12: 7350 Hz, 13: Reserved, 14: Reserved, 15: frequency is written explictly
    unsigned int private_bit : 1; ///< 私有位，编码时设置为0，解码时忽略
    unsigned int channel_configuration : 3; ///< 标识声道数
    unsigned int original_copy : 1; ///< 编码时设置为0，解码时忽略
    unsigned int home : 1; ///< 编码时设置为0，解码时忽略
    /// 可变头信息
    unsigned int copyrighted_id_bit : 1; ///< 编码时设置为0，解码时忽略
    unsigned int copyrighted_id_start : 1; ///< 编码时设置为0，解码时忽略
    unsigned int aac_frame_length : 13; ///< ADTS帧长度包括ADTS长度和AAC声音数据长度的和。即 aac_frame_length = (protection_absent == 0 ? 9 : 7) + audio_data_length
    unsigned int adts_buffer_fullness : 11; ///< 固定为0x7FF。表示是码率可变的码流
    unsigned int number_of_raw_data_blocks_in_frame : 2; ///< 表示当前帧有number_of_raw_data_blocks_in_frame + 1 个原始帧(一个AAC原始帧包含一段时间内1024个采样及相关数据)。
}__attribute__ ((packed)) Adts_header;

- (NSData *)adtsDataForPacketLength:(NSUInteger)data_length {
    static int adtsLength = 7;
    char *p_adts_header = malloc(sizeof(char) * adtsLength);
    int profile = 2; // AAC LC
    int freqIdx = 4; // 44.1KHz
    int chanCfg = 1; // CPE
    p_adts_header[0] = 0xFF;
    p_adts_header[1] = 0xF9;
    int packetLen = (int)data_length + adtsLength;
    p_adts_header[2] = (((profile - 1) << 6) + (freqIdx << 2) + (chanCfg >> 2));
    p_adts_header[3] = (((chanCfg & 3) << 6) + (packetLen >> 11));
    p_adts_header[4] = ((packetLen & 0x7FF) >> 3);
    p_adts_header[5] = (((packetLen & 0x7) << 5) | 0x1F);
    p_adts_header[6] = 0xFC;
    
    NSData *data = [NSData dataWithBytesNoCopy:p_adts_header length:adtsLength freeWhenDone:YES];
    return data;
}

@end
