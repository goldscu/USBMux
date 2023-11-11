### 项目实现内容
* Mac与iOS之间通过数据线进行通信
* 音视频采集
* 音视频编解码及播放(未做音视频同步)
  
### Mac与iOS通信
* 要想实现Mac与iOS之间通过数据线来发送数据，你只需要将本项目中的USBMux.h与USBMux.m文件加入您自己的项目中，然后参考本项目组装您自己的数据。您也可以将HZTransferData.h与HZTransferData.m文件加入到您的项目，然后增加不同的HZTransferDataType，直接按本项目的方式发送数据。
* 使用时与GCDAsyncSocket相似，iOS端作为socket的服务端，Mac端作为socket的客户端。

### 感谢
* 本项目使用了[CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket)传输数据
* 本项目参考了[usbmuxd](https://github.com/libimobiledevice/usbmuxd)实现苹果的USBMux协议


### Project implementation content
* Communication between Mac and iOS
* Audio and video collection
* Audio and video encoding, decoding and playback (no audio and video synchronization)
  
### Mac to iOS communication
* To send data through a data cable between Mac and iOS, you only need to add the USBMux.h and USBMux.m files in this project to your own project, and then refer to this project to assemble your own data. You can also add the HZTransferData.h and HZTransferData.m files to your project, then add different HZTransferDataTypes to send data directly according to the method of this project.
* It is similar to GCDAsyncSocket when used. The iOS side serves as the socket server and the Mac side serves as the socket client.

### Grateful
* This project uses [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) to transmit data
* This project refers to [usbmuxd](https://github.com/libimobiledevice/usbmuxd) to implement Apple’s USBMux protocol
