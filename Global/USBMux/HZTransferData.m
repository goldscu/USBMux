//
//  HZTransferData.m
//  USBMux_iOS
//
//  Created by 黄镇(72163106) on 2023/10/16.
//

#import "HZTransferData.h"

@implementation HZTransferData

- (instancetype)initWithDataType:(HZTransferDataType)dataType codecType:(UInt32)codecType presentationTimeStamp:(double)presentationTimeStamp data:(NSData *)data {
    if (self = [super init]) {
        _header.headerLength = sizeof(HZTransferHeader);
        _header.dataType = dataType;
        _header.codecType = codecType;
        _header.presentationTimeStamp = presentationTimeStamp;
        _header.dataLength = data.length;
        NSMutableData *mutableData = [NSMutableData data];
        [mutableData appendBytes:&_header length:_header.headerLength];
        [mutableData appendData:data];
        _all = mutableData;
        _content = data;
    }
    return self;
}

- (instancetype)initWithData:(NSData *)allData {
    if (self = [super init]) {
        _header = *(HZTransferHeader *)allData.bytes;
        _all = allData;
        _content = [allData subdataWithRange:NSMakeRange(_header.headerLength, allData.length - _header.headerLength)];
    }
    return self;
}

@end
