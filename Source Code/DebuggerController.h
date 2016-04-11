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
  volatile BOOL _giveUp;

  uint8_t _sendBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  uint8_t _recvBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  int _recvBufLen;
}

- (void) setDevicePath:(NSString *)devicePath;
- (NSString *) devicePath;

@end
