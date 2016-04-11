//
//  DebuggerController.h
//  NewTen
//
//  Created by Steve White on 4/8/16.
//
//

#import <Foundation/Foundation.h>
#import "NewtonConnection.h"

@interface DebuggerController : NSObject {
  NSString *_devicePath;
  NewtonConnection *_connection;
  BOOL _useBisyncFrames;
  volatile BOOL _giveUp;

  uint32_t _romManufacturer;
  uint32_t _hardwareType;
  uint32_t _romVersion;

  uint8_t _sendBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  uint8_t _recvBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  int _recvBufLen;
}

- (void) setUseBisyncFrames:(BOOL)useBisyncFrames;
- (BOOL) useBisyncFrames;

- (void) setDevicePath:(NSString *)devicePath;
- (NSString *) devicePath;

@end
