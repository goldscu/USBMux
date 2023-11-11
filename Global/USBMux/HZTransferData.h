//
//  HZTransferData.h
//  USBMux_iOS
//
//  Created by 黄镇(72163106) on 2023/10/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define HZUSBMuxPort 12345

typedef NS_ENUM(UInt32, HZTransferDataType) {
    HZTransferDataTypeDefalut,
    HZTransferDataTypeVideoData,
    //HZTransferDataTypeVideoVPS,
    //HZTransferDataTypeVideoSPS,
    //HZTransferDataTypeVideoPPS,
    //HZTransferDataTypeVideoPPSExtension,
};

typedef struct HZTransferHeader {
    unsigned long headerLength;
    HZTransferDataType dataType;
    UInt32 codecType;
    double presentationTimeStamp;
    unsigned long dataLength;
} HZTransferHeader;

@interface HZTransferData : NSObject

/// 数据头
@property (nonatomic, assign, readonly) HZTransferHeader header;
/// 数据的具体内容
@property (nonatomic, strong, readonly) NSData *content;
/// 包含头信息和具体内容的数据
@property (nonatomic, strong, readonly) NSData *all;

/// 用数据和头信息初始化实例
/// - Parameters:
///   - dataType: 数据类型
///   - codecType: 编码类型
///   - presentationTimeStamp: 呈现时间戳
///   - data: 具体数据
- (instancetype)initWithDataType:(HZTransferDataType)dataType codecType:(UInt32)codecType presentationTimeStamp:(double)presentationTimeStamp data:(NSData *)data;

/// 用包含头信息的数据初始化
/// - Parameter allData: 包含头信息和具体内容的数据
- (instancetype)initWithData:(NSData *)allData;

@end

NS_ASSUME_NONNULL_END
