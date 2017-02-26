//
//  DebuggerController.h
//  NewTen
//
//  Created by Steve White on 4/8/16.
//  Copyright © 2016 Steve White. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewtonConnection.h"

@protocol DebuggerControllerDelegate;

@interface DebuggerController : NSObject {
  NSString *_devicePath;
  id<DebuggerControllerDelegate> _delegate;
  
  NewtonConnection *_connection;
  BOOL _useBisyncFrames;
  BOOL _useIntegrityChecks;
  volatile BOOL _giveUp;

  uint32_t _romManufacturer;
  uint32_t _hardwareType;
  uint32_t _romVersion;
  uint32_t _romSize;

  uint8_t _sendBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  uint8_t _recvBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  int _recvBufLen;
}

- (void) cancel;

- (void) setUseBisyncFrames:(BOOL)useBisyncFrames;
- (BOOL) useBisyncFrames;

- (void) setUseIntegrityChecks:(BOOL)useIntegrityChecks;
- (BOOL) useIntegrityChecks;

- (void) setDevicePath:(NSString *)devicePath;
- (NSString *) devicePath;

- (void) setDelegate:(id<DebuggerControllerDelegate>)delegate;
- (id<DebuggerControllerDelegate>)delegate;

@end

@protocol DebuggerControllerDelegate <NSObject>
@required
- (void) debuggerControllerDidStart:(DebuggerController *)controller;
- (void) debuggerControllerDidFinish:(DebuggerController *)controller;
- (void) debuggerControllerFailedIntegrityChecks:(DebuggerController *)controller;
- (void) debuggerController:(DebuggerController *)controller updatedStatusMessage:(NSString *)statusMessage;
- (void) debuggerController:(DebuggerController *)controller retrievedManufacturer:(NSString *)manufacturer;
- (void) debuggerController:(DebuggerController *)controller retrievedHardwareType:(NSString *)hardwareType;
- (void) debuggerController:(DebuggerController *)controller retrievedROMVersion:(NSString *)romVersion;
- (void) debuggerController:(DebuggerController *)controller retrievedROMSize:(uint32_t)romSize;
- (void) debuggerController:(DebuggerController *)controller downloadedROMData:(NSData *)romData proposedFileName:(NSString *)filename;
- (void) debuggerController:(DebuggerController *)controller updatedProgressValue:(uint32_t)progressValue;

@end
