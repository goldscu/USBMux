//
//  HZAudioDecoder.h
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/30.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

extern void printAudioStreamBasicDescription(AudioStreamBasicDescription asbd);


@protocol HZAudioDecoderDelegate <NSObject>

- (void)audioDecoderDidOutputData:(NSData *)pcmData audioStreamBasicDescription:(AudioStreamBasicDescription)description;

@end


@interface HZAudioDecoder : NSObject

@property (nonatomic, weak) id<HZAudioDecoderDelegate> delegate;

- (void)decodeAudioAACData:(NSData *)aacData;
- (void)prepareDecoderWithEncodeInputStreamBasicDescription:(AudioStreamBasicDescription)encodeInputDescription encodeOutputStreamBasicDescription:(AudioStreamBasicDescription)encodeOutputDescription;

@end

NS_ASSUME_NONNULL_END
