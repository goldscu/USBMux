//
//  USBMuxManager.m
//  Socket2
//
//  Created by 黄镇(72163106) on 2023/8/23.
//

#import "USBMux.h"

static NSString *kPlistPacketTypeListen = @"Listen";
static NSString *kPlistPacketTypeConnect = @"Connect";
static NSString * const USBHubNotificationKeyMessageType = @"MessageType";
static NSString * const USBHubNotificationKeyDeviceID = @"DeviceID";

typedef NS_ENUM(uint32_t, USBMuxPacketType) {
    USBMuxPacketTypeResult = 1,
    USBMuxPacketTypeConnect = 2,
    USBMuxPacketTypeListen = 3,
    USBMuxPacketTypeDeviceAdd = 4,
    USBMuxPacketTypeDeviceRemove = 5,
    // ? = 6,
    // ? = 7,
    USBMuxPacketTypePlistPayload = 8,
    
    USBMuxPacketTypeCustomData = 10000,
};


typedef NS_ENUM(uint32_t, USBMuxPacketProtocol) {
    USBMuxPacketProtocolBinary = 0,
    USBMuxPacketProtocolPlist = 1,
};

typedef NS_ENUM(uint32_t, USBMuxReplyCode) {
    USBMuxReplyCodeOK = 0,
    USBMuxReplyCodeBadCommand = 1,
    USBMuxReplyCodeBadDevice = 2,
    USBMuxReplyCodeConnectionRefused = 3,
    // ? = 4,
    // ? = 5,
    USBMuxReplyCodeBadVersion = 6,
};

typedef struct usbmux_packet {
    uint32_t size;
    USBMuxPacketProtocol protocol;
    USBMuxPacketType type;
    uint32_t tag;
    char data[0];
} __attribute__((__packed__)) usbmux_packet_t;

//static const uint32_t kUsbmuxPacketMaxPayloadSize = UINT32_MAX - (uint32_t)sizeof(usbmux_packet_t);


@implementation USBMuxSocket

@end


typedef NS_ENUM(long, USBSocketTag) {
    USBSocketTagRead,
    USBSocketTagWriteSystemCommand,
    USBSocketTagWriteCustomData,
};


@interface USBMuxDevice() <GCDAsyncSocketDelegate>

@property (nonatomic, strong) USBMuxSocket *socket;
@property (nonatomic, strong) NSMutableArray<USBMuxSocket *> *clientSocketsArray;

@property (nonatomic, strong) NSMutableData *usbMuxReplyData;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL connected;

- (instancetype)initWithDeviceID:(NSInteger)deviceID queue:(dispatch_queue_t)queue delegate:(id<USBMuxDeviceDelegate>)aDelegate;

@end


#if TARGET_OS_OSX
static uint32_t gUSBMuxTag = 1;

@interface USBMuxManager () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) NSMutableData *usbMuxReplyData;
@property (nonatomic, strong) NSMutableArray<USBMuxDevice *> *usbMuxDevicesArray;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation USBMuxManager

#pragma mark - 单例
+ (instancetype)sharedManager {
    static USBMuxManager* muxManager = nil;
    @synchronized (self) {
        if (!muxManager) {
            muxManager = [[super allocWithZone:NULL] init];
        }
    }
    
    return muxManager ;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedManager];
}

- (id)copy {
    return [USBMuxManager sharedManager];
}

- (instancetype)init {
    if (self = [super init]) {
        self.usbMuxReplyData = [NSMutableData data];
        self.usbMuxDevicesArray = [NSMutableArray array];
        self.queue = dispatch_queue_create("USBMuxSocket", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - get set

#pragma mark - USBMux 数据
+ (NSDictionary *)packetDictionaryWithPacketType:(NSString*)messageType payload:(NSDictionary *)payload {
    NSMutableDictionary *packet = [NSMutableDictionary dictionary];
    packet[USBHubNotificationKeyMessageType] = messageType;
    
    static NSString *bundleName = nil;
    if (!bundleName) {
        NSDictionary *infoDict = [NSBundle mainBundle].infoDictionary;
        bundleName = [infoDict objectForKey:@"CFBundleName"];
    }
    if (bundleName) {
        packet[@"ProgName"] = bundleName;
    }
    static NSString *bundleVersion = nil;
    if (!bundleVersion) {
        NSDictionary *infoDict = [NSBundle mainBundle].infoDictionary;
        bundleVersion = [[infoDict objectForKey:@"CFBundleVersion"] description];
    }
    if (bundleVersion) {
        packet[@"ClientVersionString"] = bundleVersion;
    }
    
    if (payload) {
        [packet addEntriesFromDictionary:payload];
    }
    
    return [packet copy];
}

+ (NSData *)appendUSBMuxHeaderWidthData:(NSData *)data protocol:(USBMuxPacketProtocol)protocol type:(USBMuxPacketType)type tag:(uint32_t)tag {
    uint32_t headerLength = sizeof(usbmux_packet_t);
    uint32_t totalLength = headerLength + (uint32_t)data.length;
    usbmux_packet_t packet = {};
    packet.size = totalLength;
    packet.protocol = protocol;
    packet.type = type;
    packet.tag = tag;
    NSMutableData *tatalData = [NSMutableData dataWithBytes:&packet length:headerLength];
    [tatalData appendData:data];
    return tatalData;
}

- (void)analyseUSBMuxReplyData:(NSData *)data {
    [self.usbMuxReplyData appendData:data];
    while (self.usbMuxReplyData.length > 0) {
        usbmux_packet_t *packet = (usbmux_packet_t *)self.usbMuxReplyData.bytes;
        size_t totalLength = packet->size;
        //NSLog(@"收到数据:%d, type:%d, protocol:%d", packet->size, packet->type, packet->protocol);
        if ((packet->type != USBMuxPacketTypePlistPayload) || (packet->protocol != USBMuxPacketProtocolPlist)) {
            NSLog(@"协议不支持");
            NSRange range = NSMakeRange(0, self.usbMuxReplyData.length);
            [self.usbMuxReplyData replaceBytesInRange:range withBytes:NULL length:0];
            continue;
        }
        if (self.usbMuxReplyData.length < totalLength) {
            break;
        }
        uint32_t headerLength = sizeof(usbmux_packet_t);
        NSRange headerRange = NSMakeRange(0, headerLength);
        //NSData *headerData = [self.usbMuxReplyData subdataWithRange:headerRange];
        [self.usbMuxReplyData replaceBytesInRange:headerRange withBytes:NULL length:0];
        NSRange dataRange = NSMakeRange(0, totalLength - headerLength);
        NSData *data = [self.usbMuxReplyData subdataWithRange:dataRange];
        [self.usbMuxReplyData replaceBytesInRange:dataRange withBytes:NULL length:0];
        NSError *error;
        NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
        if (error) {
            NSLog(@"NSPropertyListSerialization error: %@", error);
            continue;
        }
        //NSLog(@"%@", dictionary);
        NSString *messageType = dictionary[USBHubNotificationKeyMessageType];
        if ([messageType isEqualToString:@"Attached"]) {
            NSInteger deviceID = [dictionary[@"DeviceID"] integerValue];
            USBMuxDevice *device = [[USBMuxDevice alloc] initWithDeviceID:deviceID queue:self.queue delegate:nil];
            __block BOOL hasDevice = NO;
            [self.usbMuxDevicesArray enumerateObjectsUsingBlock:^(USBMuxDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.deviceID == deviceID) {
                    hasDevice = YES;
                    *stop = YES;
                }
            }];
            if (!hasDevice) {
                [self.usbMuxDevicesArray addObject:device];
                if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxManagerDidAttachDevice:)]) {
                    [self.delegate usbMuxManagerDidAttachDevice:device];
                }
            }
        } else if ([messageType isEqualToString:@"Detached"]) {
            NSInteger deviceID = [dictionary[@"DeviceID"] integerValue];
            __block USBMuxDevice *device = nil;
            [self.usbMuxDevicesArray enumerateObjectsUsingBlock:^(USBMuxDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.deviceID == deviceID) {
                    device = obj;
                    *stop = YES;
                }
            }];
            if (device) {
                [self.usbMuxDevicesArray removeObject:device];
                if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxManagerDidDetachDevice:)]) {
                    [self.delegate usbMuxManagerDidDetachDevice:device];
                }
            }
        }
    }
}

#pragma mark - USBMux 操作
- (void)connectToUSBMuxd {
    if (!self.socket) {
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
    }
    
    if (self.socket.isConnected) {
        return;
    }
    
    NSError *error;
    NSURL *url = [NSURL URLWithString:@"/private/var/run/usbmuxd"];
    [self.socket connectToUrl:url withTimeout:-1 error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    [self.socket readDataWithTimeout:-1 tag:USBSocketTagWriteSystemCommand];
}

- (void)startListenUSB {
    [self connectToUSBMuxd];
    
    NSError *error;
    NSDictionary *dataDictionary = [USBMuxManager packetDictionaryWithPacketType:kPlistPacketTypeListen payload:nil];
    // NSPropertyListBinaryFormat_v1_0
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dataDictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    NSData *socketData = [USBMuxManager appendUSBMuxHeaderWidthData:data protocol:USBMuxPacketProtocolPlist type:USBMuxPacketTypePlistPayload tag:gUSBMuxTag++];
    [self.socket writeData:socketData withTimeout:-1 tag:USBSocketTagWriteSystemCommand];
}

- (NSArray<USBMuxDevice *> *)getUSBMuxDevices {
    __block NSArray<USBMuxDevice *> *devicesArray = nil;
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(self.queue)) {
        devicesArray = [self.usbMuxDevicesArray copy];
    } else {
        dispatch_sync(self.queue, ^{
            devicesArray = [self.usbMuxDevicesArray copy];
        });
    }
    return devicesArray;
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    //NSLog(@"%s %@", __func__, newSocket);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    //NSLog(@"%s %@ %d", __func__, host, port);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    //NSLog(@"%s %@", __func__, url);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    //NSLog(@"%s %ld %@", __func__, tag, data);
    [sock readDataWithTimeout:-1 tag:USBSocketTagRead];
    [self analyseUSBMuxReplyData:data];
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    //NSLog(@"%s %ld %ld", __func__, tag, partialLength);
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    //NSLog(@"%s %ld", __func__, tag);
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    //NSLog(@"%s %ld %ld", __func__, tag, partialLength);
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    //NSLog(@"%s %ld %f %ld", __func__, tag, elapsed, length);
    return 0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    //NSLog(@"%s %ld %f %ld", __func__, tag, elapsed, length);
    return 0;
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    //NSLog(@"%s", __func__);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    //NSLog(@"%s %@", __func__, err);
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    //NSLog(@"%s", __func__);
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
    //NSLog(@"%s", __func__);
    completionHandler(YES);
}

@end
#endif


#pragma mark - USBux实例
@implementation USBMuxDevice

- (instancetype)initWithDelegate:(id<USBMuxDeviceDelegate>)aDelegate {
    return [self initWithDeviceID:-1 queue:dispatch_queue_create("USBMuxSocket", DISPATCH_QUEUE_SERIAL) delegate:aDelegate];
}

- (instancetype)initWithDeviceID:(NSInteger)deviceID queue:(dispatch_queue_t)queue delegate:(id<USBMuxDeviceDelegate>)aDelegate {
    if (self = [super init]) {
        _deviceID = deviceID;
        self.delegate = aDelegate;
        self.queue = queue;
        self.usbMuxReplyData = [NSMutableData data];
        self.clientSocketsArray = [NSMutableArray array];
    }
    return self;
}

- (void)connectToUSBMuxd {
    if (!self.socket) {
        self.socket = [[USBMuxSocket alloc] initWithDelegate:self delegateQueue:self.queue];
    }
    
    if (self.socket.isConnected) {
        return;
    }
    
    NSError *error;
    NSURL *url = [NSURL URLWithString:@"/private/var/run/usbmuxd"];
    [self.socket connectToUrl:url withTimeout:-1 error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    [self.socket readDataWithTimeout:-1 tag:USBSocketTagRead];
}

#if TARGET_OS_OSX
- (void)connectToPort:(NSInteger)port withDelegate:(nonnull id<USBMuxDeviceDelegate>)aDelegate {
    self.delegate = aDelegate;
    [self connectToUSBMuxd];
    
    port = ((port << 8) & 0xFF00) | (port >> 8); // limit
    NSDictionary *payloadDictionary = @{
        USBHubNotificationKeyDeviceID : @(self.deviceID),
        @"PortNumber" : @(port),
    };
    NSDictionary *dataDictionary = [USBMuxManager packetDictionaryWithPacketType:kPlistPacketTypeConnect payload:payloadDictionary];
    NSError *error;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dataDictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    NSData *socketData = [USBMuxManager appendUSBMuxHeaderWidthData:data protocol:USBMuxPacketProtocolPlist type:USBMuxPacketTypePlistPayload tag:gUSBMuxTag++];
    [self.socket writeData:socketData withTimeout:-1 tag:USBSocketTagWriteSystemCommand];
}
#endif

- (void)disconnect {
    [self.socket disconnect];
    self.socket = nil;
}

#if TARGET_OS_OSX
- (void)writeData:(NSData *)data {
    if (data.length <= 0) {
        NSLog(@"data <= 0");
        return;
    }
    
    if (!self.socket.isConnected) {
        NSLog(@"Unconnected");
        return;
    }
    usbmux_packet_t header = {};
    uint32_t headerLength = sizeof(usbmux_packet_t);
    header.size = (uint32_t)data.length + headerLength;
    header.protocol = USBMuxPacketProtocolBinary;
    header.type = USBMuxPacketTypeCustomData;
    header.tag = 0;
    NSMutableData *customData = [NSMutableData dataWithBytes:&header length:headerLength];
    [customData appendData:data];
    [self.socket writeData:customData withTimeout:-1 tag:USBSocketTagWriteCustomData];
}
#else
- (void)writeData:(NSData *)data useClientSocket:(GCDAsyncSocket *)clientSocket {
    if (data.length <= 0) {
        NSLog(@"data <= 0");
        return;
    }
    if (!clientSocket) {
        NSLog(@"No clientSocket");
        return;
    }
    usbmux_packet_t header = {};
    uint32_t headerLength = sizeof(usbmux_packet_t);
    header.size = (uint32_t)data.length + headerLength;
    header.protocol = USBMuxPacketProtocolBinary;
    header.type = USBMuxPacketTypeCustomData;
    header.tag = 0;
    NSMutableData *customData = [NSMutableData dataWithBytes:&header length:headerLength];
    [customData appendData:data];
    [clientSocket writeData:customData withTimeout:-1 tag:USBSocketTagWriteCustomData];
}

- (BOOL)acceptOnPort:(uint16_t)port error:(NSError **)errPtr {
    if (!self.socket) {
        self.socket = [[USBMuxSocket alloc] initWithDelegate:self delegateQueue:self.queue];
    }
    return [self.socket acceptOnPort:port error:errPtr];
}

- (NSArray<USBMuxSocket *> *)getClientSockets {
    __block NSArray<USBMuxSocket *> *clientSocketsArray = nil;
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(self.queue)) {
        clientSocketsArray = [self.clientSocketsArray copy];
    } else {
        dispatch_sync(self.queue, ^{
            clientSocketsArray = [self.clientSocketsArray copy];
        });
    }
    return clientSocketsArray;
}
#endif

- (void)analyseUSBMuxReplyData:(NSData *)replyData fromSocket:(USBMuxSocket *)socket {
    [self.usbMuxReplyData appendData:replyData];
    while (self.usbMuxReplyData.length > 0) {
        usbmux_packet_t *packet = (usbmux_packet_t *)self.usbMuxReplyData.bytes;
        size_t totalLength = packet->size;
        //NSLog(@"收到数据:%d, type:%d, protocol:%d", packet->size, packet->type, packet->protocol);
        if ((packet->type == USBMuxPacketTypePlistPayload) && (packet->protocol == USBMuxPacketProtocolPlist)) {
            if (self.usbMuxReplyData.length < totalLength) {
                break;
            }
            uint32_t headerLength = sizeof(usbmux_packet_t);
            NSRange headerRange = NSMakeRange(0, headerLength);
            //NSData *headerData = [self.usbMuxReplyData subdataWithRange:headerRange];
            [self.usbMuxReplyData replaceBytesInRange:headerRange withBytes:NULL length:0];
            NSRange dataRange = NSMakeRange(0, totalLength - headerLength);
            NSData *data = [self.usbMuxReplyData subdataWithRange:dataRange];
            [self.usbMuxReplyData replaceBytesInRange:dataRange withBytes:NULL length:0];
            NSError *error;
            NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
            if (error) {
                NSLog(@"NSPropertyListSerialization error: %@", error);
                continue;
            }
            NSLog(@"%@", dictionary);
            NSString *messageType = dictionary[USBHubNotificationKeyMessageType];
            if ([messageType isEqualToString:@"Result"]) {
                NSNumber *number = dictionary[@"Number"];
                if (number.longValue == USBMuxReplyCodeOK) {
#if TARGET_OS_OSX
                    self.connected = YES;
                    if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxDeviceDidConnect:)]) {
                        [self.delegate usbMuxDeviceDidConnect:self];
                    }
#endif
                } else {
                    self.socket.delegate = nil;
                    [self.socket disconnect];
                    self.socket = nil;
                }
            }
        } else if ((packet->type == USBMuxPacketTypeCustomData) && (packet->protocol == USBMuxPacketProtocolBinary)) {
            if (self.usbMuxReplyData.length < totalLength) {
                break;
            }
            uint32_t headerLength = sizeof(usbmux_packet_t);
            NSRange headerRange = NSMakeRange(0, headerLength);
            //NSData *headerData = [self.usbMuxReplyData subdataWithRange:headerRange];
            [self.usbMuxReplyData replaceBytesInRange:headerRange withBytes:NULL length:0];
            NSRange dataRange = NSMakeRange(0, totalLength - headerLength);
            NSData *data = [self.usbMuxReplyData subdataWithRange:dataRange];
            [self.usbMuxReplyData replaceBytesInRange:dataRange withBytes:NULL length:0];
            if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxDevice:didReadData:fromSocket:)]) {
                [self.delegate usbMuxDevice:self didReadData:data fromSocket:socket];
            }
        } else {
            NSLog(@"Unsupported protocol");
            NSRange range = NSMakeRange(0, self.usbMuxReplyData.length);
            [self.usbMuxReplyData replaceBytesInRange:range withBytes:NULL length:0];
            break;
        }
    }
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(USBMuxSocket *)sock didAcceptNewSocket:(USBMuxSocket *)newSocket {
    //NSLog(@"%s %@", __func__, newSocket);
    [newSocket readDataWithTimeout:-1 tag:USBSocketTagRead];
#if TARGET_OS_OSX
    if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxDeviceDidDisconnect:)]) {
        [self.delegate usbMuxDeviceDidDisconnect:self];
    }
#else
    newSocket.delegate = self;
    [self.clientSocketsArray addObject:newSocket];
    if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxDevice:didConnectToSocket:)]) {
        [self.delegate usbMuxDevice:self didConnectToSocket:newSocket];
    }
#endif
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    //NSLog(@"%s %@ %d", __func__, host, port);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    //NSLog(@"%s %@", __func__, url);
}

- (void)socket:(USBMuxSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    //NSLog(@"%s %ld %@ %@", __func__, tag, sock, data);
    [sock readDataWithTimeout:-1 tag:USBSocketTagRead];
    [self analyseUSBMuxReplyData:data fromSocket:sock];
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"%s %ld %ld", __func__, tag, partialLength);
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    //NSLog(@"%s %ld", __func__, tag);
    if (tag == USBSocketTagWriteCustomData) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxDeviceDidWriteData:)]) {
            [self.delegate usbMuxDeviceDidWriteData:self];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    //NSLog(@"%s %ld %ld", __func__, tag, partialLength);
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    //NSLog(@"%s %ld %f %ld", __func__, tag, elapsed, length);
    return 0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    //NSLog(@"%s %ld %f %ld", __func__, tag, elapsed, length);
    return 0;
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    //NSLog(@"%s", __func__);
}

- (void)socketDidDisconnect:(USBMuxSocket *)sock withError:(nullable NSError *)err {
    //NSLog(@"%s %@ %@", __func__, sock, err);
#if TARGET_OS_OSX
    [self.socket disconnect];
    self.socket = nil;
    if (self.connected) {
        self.connected = NO;
        if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxDeviceDidDisconnect:)]) {
            [self.delegate usbMuxDeviceDidDisconnect:self];
        }
    }
#else
    if (sock == self.socket) {
        [self.clientSocketsArray enumerateObjectsUsingBlock:^(GCDAsyncSocket * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj disconnect];
        }];
        [self.clientSocketsArray removeAllObjects];
        [self.socket disconnect];
        self.socket = nil;
    } else if ([self.clientSocketsArray containsObject:sock]) {
        [sock disconnect];
        [self.clientSocketsArray removeObject:sock];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(usbMuxDevice:clientSocketDidDisconnect:)]) {
        [self.delegate usbMuxDevice:self clientSocketDidDisconnect:sock];
    }
#endif
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    //NSLog(@"%s", __func__);
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
    //NSLog(@"%s", __func__);
    completionHandler(YES);
}

@end
