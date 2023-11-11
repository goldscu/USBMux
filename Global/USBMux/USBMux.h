//
//  USBMuxManager.h
//  Socket2
//
//  Created by 黄镇(72163106) on 2023/8/23.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>
#import <TargetConditionals.h>

NS_ASSUME_NONNULL_BEGIN


@protocol USBMuxDeviceDelegate;

/// Socket对象，用于USB实际传输数据
@interface USBMuxSocket : GCDAsyncSocket

@end

/// USB设备对象，一个USBMuxDevice表示一个USB设备，Mac 端作为 socket 的客户端使用，iOS等端作为 socket 的服务端使用
@interface USBMuxDevice : NSObject

/// Mac端为USBMuxd返回的正整数，标识一个USB接口；非Mac端为-1
@property (nonatomic, assign, readonly) NSInteger deviceID;
@property (nonatomic, weak) id<USBMuxDeviceDelegate> delegate;

#if TARGET_OS_OSX
/// 连接到端口，Mac端调用此方法
/// - Parameters:
///   - port: 手机端正在监听的端口
///   - aDelegate: 回调类
- (void)connectToPort:(NSInteger)port withDelegate:(id<USBMuxDeviceDelegate>)aDelegate;
/// Mac端发送数据
/// - Parameters:
///   - data: 要发送的数据
- (void)writeData:(NSData *)data;
#else
/// iOS等端初始化方法
/// - Parameter aDelegate: 回调对象
- (instancetype)initWithDelegate:(id<USBMuxDeviceDelegate>)aDelegate;
/// 监听端口，iOS等端调用此方法
/// - Parameters:
///   - port: 手机要监听的端口
///   - errPtr: 是否有错误
- (BOOL)acceptOnPort:(uint16_t)port error:(NSError **)errPtr;
/// iOS等端发送数据
/// - Parameters:
///   - data: 要发送的数据
///   - clientSocket: 发送给哪个客户端，代理方法 -[USBMuxDeviceDelegate usbMuxDevice:didConnectToSocket:] 在每个客户端连接成功后会将其返回
- (void)writeData:(NSData *)data useClientSocket:(USBMuxSocket *)clientSocket;
/// 获取所有的客户端。代理方法 -[USBMuxDeviceDelegate usbMuxDevice:didConnectToSocket:] 在每个客户端连接成功后会将其返回
- (NSArray<USBMuxSocket *> *)getClientSockets;
#endif
/// Mac端用 USBMuxManager 获取设备实例，iOS等端使用 -[USBMuxDevice initWithDelegate:] 方法初始化
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/// 断开连接
- (void)disconnect;

@end


#if TARGET_OS_OSX
/// USB设备管理单例回调
@protocol USBMuxManagerDelegate <NSObject>

@optional
/// 有一个设备连接上了。调用 -[USBMuxManager startListenUSB]，会多次回调此方法返回所有已连接设备
- (void)usbMuxManagerDidAttachDevice:(USBMuxDevice *)device;
/// 有一个设备断开连接了
- (void)usbMuxManagerDidDetachDevice:(USBMuxDevice *)device;

@end


/// USB设备管理单例
@interface USBMuxManager : NSObject

@property (nonatomic, weak) id<USBMuxManagerDelegate> delegate;

/// 获取单例。最好不要一直调用此方法。
+ (instancetype)sharedManager;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 开始监听USB设备连接断开情况
- (void)startListenUSB;
/// 获取所有的USB设备
- (NSArray<USBMuxDevice *> *)getUSBMuxDevices;

@end
#endif

/// USB设备回调协议
@protocol USBMuxDeviceDelegate <NSObject>

@optional
#if TARGET_OS_OSX
- (void)usbMuxDeviceDidConnect:(USBMuxDevice *)device;
- (void)usbMuxDeviceDidDisconnect:(USBMuxDevice *)device;
#else
/// iOS等端监听设备连接情况
/// - Parameters:
///   - device: USB设备
///   - clientSocket: 客户端Socket，请不要直接使用USBMuxSocket发送数据，没有按照苹果USBMux协议加协议头的话，内部数据处理会发生错误
- (void)usbMuxDevice:(USBMuxDevice *)device didConnectToSocket:(USBMuxSocket *)clientSocket;

/// iOS等端监听设备断开情况
/// - Parameters:
///   - device: USB设备
///   - clientSocket: 客户端Socket，可能是监听的Socket，也可能是传输数据的Socket
- (void)usbMuxDevice:(USBMuxDevice *)device clientSocketDidDisconnect:(USBMuxSocket *)clientSocket;
#endif

/// 收到数据回调
/// - Parameters:
///   - device: USB设备
///   - data: 收到的数据
///   - socket: 接收数据的socket
- (void)usbMuxDevice:(USBMuxDevice *)device didReadData:(NSData *)data fromSocket:(USBMuxSocket *)socket;

/// 发送完数据回调
- (void)usbMuxDeviceDidWriteData:(USBMuxDevice *)device;

@end

NS_ASSUME_NONNULL_END
