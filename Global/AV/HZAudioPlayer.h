//
//  HZAudioPlayer.h
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/21.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HZAudioPlayer : NSObject

- (void)playSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)playData:(NSData *)pcmData withAudioStreamBasicDescription:(AudioStreamBasicDescription)description;
- (NSUInteger)getCurrentPcmDataLenght;
- (void)clearPcmData;

@end

NS_ASSUME_NONNULL_END
