//
//  HZAudioEncoder.h
//  AVDemo
//
//  Created by 黄镇(72163106) on 2022/11/30.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

void printAudioStreamBasicDescription(AudioStreamBasicDescription asbd);

@protocol HZAudioEncoderDelegate<NSObject>

- (void)audioEncoderDidUseInputStreamBasicDescription:(AudioStreamBasicDescription)inputStreamBasicDescription outputStreamBasicDescription:(AudioStreamBasicDescription)outputStreamBasicDescription;
- (void)audioEncoderDidOutputData:(NSData *)aacData pts:(CMTime)pts;

@end


@interface HZAudioEncoder : NSObject

@property (nonatomic, weak) id<HZAudioEncoderDelegate> delegate;

- (void)encodeAudioSamepleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
