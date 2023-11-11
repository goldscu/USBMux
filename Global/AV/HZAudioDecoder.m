//
//  HZAudioDecoder.m
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/30.
//

#import "HZAudioDecoder.h"

typedef struct {
    char * data;
    UInt32 size;
    UInt32 channelCount;
    AudioStreamPacketDescription packetDesc;
} CCAudioUserData;

@interface HZAudioDecoder ()

@property (nonatomic, strong) dispatch_queue_t decoderQueue;
@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic, strong) NSData *aacData;
@property (nonatomic, assign) AudioStreamBasicDescription inputStreamBasicDescription;
@property (nonatomic, assign) AudioStreamBasicDescription outputStreamBasicDescription;

@end

static AudioStreamPacketDescription gHZOutDataPacketDescription;
static OSStatus audioDecoderInputDataProc(AudioConverterRef inAudioConverter,
                                          UInt32 *ioNumberDataPackets,
                                          AudioBufferList *ioData,
                                          AudioStreamPacketDescription **outDataPacketDescription,
                                          void *inUserData) {
    HZAudioDecoder *audioDecoder = (__bridge HZAudioDecoder *)(inUserData);
    //填充数据
    *outDataPacketDescription = &gHZOutDataPacketDescription;
    gHZOutDataPacketDescription.mStartOffset = 0;
    gHZOutDataPacketDescription.mDataByteSize = (UInt32)audioDecoder.aacData.length;
    gHZOutDataPacketDescription.mVariableFramesInPacket = 0;
    
    //NSLog(@"音频解码 回调 %lu", (unsigned long)audioDecoder.aacData.length);
    ioData->mBuffers[0].mData = (void *)audioDecoder.aacData.bytes;
    ioData->mBuffers[0].mDataByteSize = (UInt32)audioDecoder.aacData.length;
    ioData->mBuffers[0].mNumberChannels = audioDecoder.inputStreamBasicDescription.mChannelsPerFrame;
    
    return noErr;
}

@implementation HZAudioDecoder
- (void)dealloc {
    if (self.audioConverter) {
        AudioConverterDispose(self.audioConverter);
        self.audioConverter = NULL;
    }
}

- (instancetype)init {
    if (self = [super init]) {
        self.decoderQueue = dispatch_queue_create("aac hard decoder queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)prepareDecoderWithEncodeInputStreamBasicDescription:(AudioStreamBasicDescription)encodeInputDescription encodeOutputStreamBasicDescription:(AudioStreamBasicDescription)encodeOutputDescription {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.decoderQueue, ^{
        [weakSelf _prepareDecoderWithEncodeInputStreamBasicDescription:encodeInputDescription encodeOutputStreamBasicDescription:encodeOutputDescription];
    });
}

- (void)_prepareDecoderWithEncodeInputStreamBasicDescription:(AudioStreamBasicDescription)encodeInputDescription encodeOutputStreamBasicDescription:(AudioStreamBasicDescription)encodeOutputDescription {
    _outputStreamBasicDescription.mSampleRate = encodeInputDescription.mSampleRate; //采样率
    _outputStreamBasicDescription.mChannelsPerFrame = encodeInputDescription.mChannelsPerFrame; //输出声道数
    _outputStreamBasicDescription.mFormatID = kAudioFormatLinearPCM; //输出格式
    _outputStreamBasicDescription.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked); //编码 12
    _outputStreamBasicDescription.mFramesPerPacket = encodeInputDescription.mFramesPerPacket; //每一个packet帧数 ；
    _outputStreamBasicDescription.mBitsPerChannel = encodeInputDescription.mBitsPerChannel; //数据帧中每个通道的采样位数。
    _outputStreamBasicDescription.mBytesPerFrame = _outputStreamBasicDescription.mBitsPerChannel / 8 * _outputStreamBasicDescription.mChannelsPerFrame; //每一帧大小（采样位数 / 8 *声道数）一般是1或者2
    _outputStreamBasicDescription.mBytesPerPacket = _outputStreamBasicDescription.mBytesPerFrame * _outputStreamBasicDescription.mFramesPerPacket; //每个packet大小（帧大小 * 帧数）
    _outputStreamBasicDescription.mReserved =  0;                                  //对其方式 0(8字节对齐)

    _inputStreamBasicDescription.mSampleRate = encodeOutputDescription.mSampleRate;
    _inputStreamBasicDescription.mFormatID = encodeOutputDescription.mFormatID;
    _inputStreamBasicDescription.mFormatFlags = encodeOutputDescription.mFormatFlags;
    _inputStreamBasicDescription.mFramesPerPacket = encodeOutputDescription.mFramesPerPacket;
    _inputStreamBasicDescription.mChannelsPerFrame = encodeOutputDescription.mChannelsPerFrame;
    
    NSLog(@"音频解码 输入参数：");
    printAudioStreamBasicDescription(self.inputStreamBasicDescription);
    NSLog(@"音频解码 输出参数：");
    printAudioStreamBasicDescription(self.outputStreamBasicDescription);
    
    UInt32 inDesSize = sizeof(_inputStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &inDesSize, &_inputStreamBasicDescription);
    
    //获取解码器的描述信息(只能传入software)
    
    AudioClassDescription *audioClassDesc = [self getAudioCalssDescriptionWithType:_outputStreamBasicDescription.mFormatID];
    OSStatus status = AudioConverterNewSpecific(&_inputStreamBasicDescription, &_outputStreamBasicDescription, 1, audioClassDesc, &_audioConverter);
    if (status != noErr) {
        NSLog(@"AudioConverterNewSpecific 出错 %d", (int)status);
        return;
    }
}

- (AudioClassDescription *)getAudioCalssDescriptionWithType:(AudioFormatID)type {
    static AudioClassDescription desc;
    UInt32 decoderSpecific = type;
    UInt32 size;
    OSStatus status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders, sizeof(decoderSpecific), &decoderSpecific, &size);
    if (status != noErr) {
        NSLog(@"Error！：硬解码AAC get info 失败, status= %d", (int)status);
        return nil;
    }
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription description[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(decoderSpecific), &decoderSpecific, &size, &description);
    if (status != noErr) {
        NSLog(@"Error！：硬解码AAC get propery 失败, status= %d", (int)status);
        return nil;
    }
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

- (void)decodeAudioAACData:(NSData *)aacData {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.decoderQueue, ^{
        if (!weakSelf.audioConverter) {
            return;
        }
        
        [weakSelf _decodeAudioAACData:aacData];
    });
}

- (void)_decodeAudioAACData:(NSData *)aacData {
    self.aacData = aacData;
    //NSLog(@"音频解码 输入 %lu", (unsigned long)aacData.length);
    //输出大小和packet个数
    UInt32 pcmBufferSize = (UInt32)(2048 * self.outputStreamBasicDescription.mChannelsPerFrame);
    UInt32 pcmDataPacketSize = self.inputStreamBasicDescription.mFramesPerPacket;
    //创建临时容器pcm
    uint8_t *pcmBuffer = malloc(pcmBufferSize);
    memset(pcmBuffer, 0, pcmBufferSize);
    //输出buffer
    AudioBufferList outAudioBufferList = {0};
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = self.outputStreamBasicDescription.mChannelsPerFrame;
    outAudioBufferList.mBuffers[0].mDataByteSize = pcmBufferSize;
    outAudioBufferList.mBuffers[0].mData = pcmBuffer;
    //输出描述
    AudioStreamPacketDescription outputPacketDesc = {0};
    //配置填充函数，获取输出数据
    OSStatus status = AudioConverterFillComplexBuffer(self.audioConverter, &audioDecoderInputDataProc, (__bridge void *)self, &pcmDataPacketSize, &outAudioBufferList, &outputPacketDesc);
    if (status == noErr) {
        if (outAudioBufferList.mBuffers[0].mDataByteSize > 0) {
            //NSLog(@"音频解码 输出 %lu", (unsigned long)outAudioBufferList.mBuffers[0].mDataByteSize);
            NSData *rawData = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            if (self.delegate && [self.delegate respondsToSelector:@selector(audioDecoderDidOutputData:audioStreamBasicDescription:)]) {
                [self.delegate audioDecoderDidOutputData:rawData audioStreamBasicDescription:self.outputStreamBasicDescription];
            }
        }
    } else {
        NSLog(@"AudioConverterFillComplexBuffer %d", status);
    }
    //如果获取到数据
    free(pcmBuffer);
}

@end
