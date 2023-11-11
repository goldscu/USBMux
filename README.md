# 项目实现内容
* Mac与iOS之间通信
* 音视频采集
* 音视频编解码及播放(未做音视频同步)
  
# Mac与iOS通信
要想实现Mac与iOS之间通过数据线来发送数据，你只需要将本项目中的USBMux.h与USBMux.m文件加入您自己的项目中，然后参考本项目组装您自己的数据。您也可以将HZTransferData.h与HZTransferData.m文件加入到您的项目，然后增加不同的HZTransferDataType，直接按本项目的方式发送数据。

使用时与GCDAsyncSocket相似，iOS端作为socket的服务端，Mac端作为socket的客户端。

# 感谢
1 本项目使用了[CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket)传输数据
2 本项目参考了[usbmuxd](https://github.com/libimobiledevice/usbmuxd)实现苹果的USBMux协议
