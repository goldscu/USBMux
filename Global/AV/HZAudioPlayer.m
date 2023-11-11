//
//  HZAudioPlayer.m
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/21.
//

#import "HZAudioPlayer.h"
#import <AudioUnit/AudioUnit.h>


const static UInt32 kOutputBus = 0;
//const static UInt32 kInputBus = 1;

static OSStatus c_playCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData);


void printAudioStreamBasicDescription(AudioStreamBasicDescription asbd) {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("====== AudioStreamBasicDescription begin ===========\n");
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("====== AudioStreamBasicDescription end ===========\n");
}


@interface HZAudioPlayer ()

@property (nonatomic, assign) AUGraph graph;
@property (nonatomic, assign) AudioUnit audioUnit;
@property (nonatomic, strong) NSMutableData *pcmBufferData;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation HZAudioPlayer

- (void)dealloc {
    if (self.audioUnit) {
        AudioComponentInstanceDispose(self.audioUnit);
        self.audioUnit = NULL;
    }
}

- (instancetype)init {
    if (self = [super init]) {
        self.pcmBufferData = [[NSMutableData alloc] init];
        self.queue = dispatch_queue_create("HZAudioUnitPlayQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSUInteger)getCurrentPcmDataLenght {
    __block NSUInteger lenght = 0;
    dispatch_sync(self.queue, ^{
        lenght = self.pcmBufferData.length;
    });
    return lenght;
}

- (void)clearPcmData {
    dispatch_sync(self.queue, ^{
        [self.pcmBufferData replaceBytesInRange:NSMakeRange(0, self.pcmBufferData.length) withBytes:NULL length:0];
    });
}

- (void)playData:(NSData *)pcmData withAudioStreamBasicDescription:(AudioStreamBasicDescription)description {
    dispatch_async(self.queue, ^{
        if (!self.audioUnit) {
            [self prepareAudioUnitWithAudioStreamBasicDescription:description];
        }
        //NSLog(@"音频未播完数据：%lu", (unsigned long)self.pcmBufferData.length);
        [self.pcmBufferData appendBytes:pcmData.bytes length:pcmData.length];
    });
}

- (void)playSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CFRetain(sampleBuffer);
    dispatch_async(self.queue, ^{
        if (!self.audioUnit) {
            CMAudioFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
            AudioStreamBasicDescription outputFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
            [self prepareAudioUnitWithAudioStreamBasicDescription:outputFormat];
        }
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t length = 0;
        char *pointer = NULL;
        CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &length, &pointer);
        [self.pcmBufferData appendBytes:pointer length:length];
        CFRelease(sampleBuffer);
    });
}

- (void)prepareGraphWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // AVAudioSession
#if TARGET_OS_IPHONE
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    [audioSession setActive:YES error:&error];
#endif
    
    // graph
    OSStatus status = noErr;
    status = NewAUGraph(&_graph);
    if (status) {
        NSLog(@"NewAUGraph: %d", status);
    }
    AudioComponentDescription audioDesc = {};
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode remoteIONote;
    status = AUGraphAddNode(self.graph, &audioDesc, &remoteIONote);
    if (status) {
        NSLog(@"AUGraphAddNode: %d", status);
    }
    status = AUGraphOpen(self.graph);
    if (status) {
        NSLog(@"AUGraphOpen: %d", status);
    }
    status = AUGraphNodeInfo(self.graph, remoteIONote, &audioDesc, &_audioUnit);
    if (status) {
        NSLog(@"AUGraphOpen: %d", status);
    }
    
    // unit
    UInt32 enableFlag = 1;
    /*status = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &enableFlag, sizeof(enableFlag));
    if (status) {
        NSLog(@"SetProperty EnableIO: %d", status);
    }*/
    status = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &enableFlag, sizeof(enableFlag));
    if (status) {
        NSLog(@"SetProperty EnableIO: %d", status);
    }
    // format
    CMAudioFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    AudioStreamBasicDescription streamFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    printAudioStreamBasicDescription(streamFormat);
    status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &streamFormat, sizeof(streamFormat));
    if (status) {
        NSLog(@"SetProperty StreamFormat: %d", status);
    }
    /*status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &streamFormat, sizeof(streamFormat));
    if (status) {
        NSLog(@"SetProperty StreamFormat: %d", status);
    }*/
    
    //Set up input callback
    AURenderCallbackStruct input;
    input.inputProc = c_playCallback;
    input.inputProcRefCon = (__bridge void *)self;
    AudioUnitElement element = 0; // imput mic
    status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, element, &input, sizeof(input));
    if (status) {
        NSLog(@"SetProperty SetRenderCallback: %d", status);
    }
    UInt32 echoCancellationStatus = 0; // 0 生效，1 无效
    status = AudioUnitSetProperty(self.audioUnit, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Output, kOutputBus, &echoCancellationStatus, sizeof(echoCancellationStatus));
    if (status) {
        NSLog(@"SetProperty BypassVoiceProcessing: %d", status);
    }
    status = AUGraphInitialize(self.graph);
    if (status) {
        NSLog(@"AUGraphInitialize: %d", status);
    }
    status = AUGraphStart(self.graph);
    if (status) {
        NSLog(@"AUGraphStart: %d", status);
    }
}

- (void)prepareAudioUnitWithAudioStreamBasicDescription:(AudioStreamBasicDescription)outputFormat {
//    NSError *error = nil;
//    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
//    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&error];
//    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
//    [audioSession setActive:YES error:&error];
    
    OSStatus status = noErr;
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_OSX
    audioDesc.componentSubType = kAudioUnitSubType_Delay;
#endif
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &_audioUnit);
    //audio property
    UInt32 flag = 1;
    status = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flag, sizeof(flag));
    if (status) {
        NSLog(@"SetProperty EnableIO: %d", status);
    }
    // format
    NSLog(@"播放参数：");
    printAudioStreamBasicDescription(outputFormat);
    status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &outputFormat, sizeof(outputFormat));
    if (status) {
        NSLog(@"SetProperty StreamFormat: %d", status);
    }
    // callback
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = c_playCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, kOutputBus, &playCallback, sizeof(playCallback));
    if (status) {
        NSLog(@"SetProperty SetRenderCallback: %d", status);
    }
    status = AudioUnitInitialize(self.audioUnit);
    if (status) {
        NSLog(@"AudioUnitInitialize: %d", status);
    }
    status = AudioOutputUnitStart(self.audioUnit);
    if (status) {
        NSLog(@"AudioOutputUnitStart: %d", status);
    }
}

- (void)stop {
    AudioOutputUnitStop(self.audioUnit);
}

@end



static OSStatus c_playCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    HZAudioPlayer *player = (__bridge HZAudioPlayer *)inRefCon;
    AudioBuffer buffer = ioData->mBuffers[0];
    if (player.pcmBufferData.length > 0) {
        UInt32 size = (UInt32)MIN(buffer.mDataByteSize, player.pcmBufferData.length);
        memcpy(buffer.mData, player.pcmBufferData.bytes, size);
        buffer.mDataByteSize = size;
        [player.pcmBufferData replaceBytesInRange:NSMakeRange(0, size) withBytes:NULL length:0];
        //NSLog(@"播放 %d 还剩 %lu", size, (unsigned long)player.data.length);
    } else {
        //NSLog(@"静音");
        buffer.mDataByteSize = 0;
        buffer.mData = NULL;
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
    }
    return noErr;
}

/*static OSStatus c_recordCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    HZAudioPlayer *player = (__bridge HZAudioPlayer *)inRefCon;
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;
    // 获得录制的采样数据
    OSStatus status = AudioUnitRender(player.audioUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      kInputBus,
                                      inNumberFrames,
                                      &(bufferList));
    if (!status) {
        NSLog(@"c_recordCallback AudioUnitRender %d", (int)status);
    }
    return noErr;
}*/
