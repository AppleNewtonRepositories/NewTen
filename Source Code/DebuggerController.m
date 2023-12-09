//
//  DebuggerController.m
//  NewTen
//
//  Created by Steve White on 4/8/16.
//  Copyright © 2016 Steve White. All rights reserved.
//

#import "DebuggerController.h"

#import "AppDelegate.h"
#import "NewtonConnection.h"

#define DEBUG 0

// From http://newton.vyx.net/revenge/
enum {
  CommandOpen = 0x00,
  CommandClose = 0x01,
  CommandReadMemory = 0x02,
  CommandWriteMemory = 0x03,
  CommandReadRegisters = 0x08,
  CommandWriteRegisters = 0x09,
  CommandExecute = 0x10,
  CommandReadPhysicalMemory = 0x18,
  CommandWritePhysicalMemory = 0x19,
  CommandUnknown = 0x1a,
  CommandStop = 0x1b,
  CommandGo = 0x1c,
  CommandAck = 0x40,
  CommandPing = 0x78,
};

enum {
  ResponseStopWithStatus = 0x20,
  ResponseFatal = 0x5e,
  ResponseResult = 0x5f,
  ResponseError = 0x60,
  ResponsePong = 0x79,
  ResponseReset = 0x7f,
  ResponseInquiry = 0x80,
};

@implementation DebuggerController

- (id) init {
  self = [super init];
  if (self != nil) {
    _useIntegrityChecks = YES;
  }
  return self;
}

- (void) dealloc {
  if (_devicePath) {
    [_devicePath release], _devicePath = nil;
  }
  if (_connection) {
    [_connection release], _connection = nil;
  }
  
  [super dealloc];
}

- (void) cancel {
  [_connection cancel];
  _giveUp = YES;
}

- (void) setDevicePath:(NSString *)devicePath {
  if (_devicePath) {
    [_devicePath release], _devicePath = nil;
  }
  _devicePath = [devicePath retain];
}

- (NSString *) devicePath {
  return [[_devicePath retain] autorelease];
}

- (void) setUseBisyncFrames:(BOOL)useBisyncFrames {
  _useBisyncFrames = useBisyncFrames;
}

- (BOOL) useBisyncFrames {
  return _useBisyncFrames;
}

- (void) setUseIntegrityChecks:(BOOL)useIntegrityChecks {
  _useIntegrityChecks = useIntegrityChecks;
}

- (BOOL) useIntegrityChecks {
  return _useIntegrityChecks;
}

- (void) setDelegate:(id<DebuggerControllerDelegate>)delegate {
  _delegate = delegate;
}

- (id<DebuggerControllerDelegate>) delegate {
  return _delegate;
}

#pragma mark - Reading
- (BOOL) readResponseOfLength:(uint8_t)length {
  int status = 0;
  
  memset(_recvBuf, 0x00, sizeof(_recvBuf));
  _recvBufLen = 0;
  
  while ( true )
  {
    if ([self useBisyncFrames] == YES) {
      status = [_connection receiveFrame:_recvBuf length:&_recvBufLen];
    }
    else {
      status = [_connection readData:_recvBuf length:length];
    }
    
    if (status >= 0) {
      break;
    }
    
    if ( _giveUp ) {
      [[NSException exceptionWithName:@"DebuggerControllerCancelled" reason:@"_giveUp == true" userInfo:nil] raise];
      return NO;
    }
  }
  
  return YES;
}

- (BOOL) readDataForResponse:(uint8_t)response length:(uint8_t)length {
  while (true) {
    BOOL success = [self readResponseOfLength:length];
    if (success == NO) {
      return NO;
    }
    
    if (_giveUp == true) {
      return NO;
    }
    
    if (_recvBuf[0] == response) {
      return YES;
    }
  }

  return NO;
}

- (BOOL) readDataForResponse:(uint8_t)response {
  return [self readDataForResponse:response length:0];
}

#pragma mark - Sending
- (void) sendRequestWithCommand:(uint8_t)command body:(uint8_t *)body length:(uint8_t)length {
  memset(_sendBuf, 0x00, sizeof(_sendBuf));
  _sendBuf[0] = command;
  
  if (length > 0) {
    if (length - 1 > sizeof(_sendBuf)) {
      NSLog(@"Length would exceed _sendBuf size. truncating!");
      length = (uint8_t)sizeof(_sendBuf) - 1;
    }
    memcpy(&_sendBuf[1], body, length);
  }
  
  if ([self useBisyncFrames] == YES) {
    [_connection sendFrame:&_sendBuf[0] header:NULL length:length + 1];
  }
  else {
    [_connection sendData:&_sendBuf[0] length:length + 1];
  }
  
  if (_giveUp == true) {
    [[NSException exceptionWithName:@"DebuggerControllerCancelled" reason:@"_giveUp == true" userInfo:nil] raise];
  }
}

#pragma mark - Debugger commands
- (void) sendRequestWithCommand:(uint8_t)command {
  [self sendRequestWithCommand:command body:NULL length:0];
}

- (void) sendCloseCommand {
  [self sendRequestWithCommand:CommandClose];
}

- (void) sendGoCommand {
  [self sendRequestWithCommand:CommandAck];
  
  uint8_t goCommand[] = { 0x00, 0x00, 0x00, 0x00 };
  [self sendRequestWithCommand:CommandGo body:&goCommand[0] length:sizeof(goCommand)];
  [self readDataForResponse:ResponseResult];
}

- (void) sendStopCommand {
  uint8_t stopCmd[] = { 'S', 'T', 'O', 'P'};
  [self sendRequestWithCommand:CommandStop body:&stopCmd[0] length:sizeof(stopCmd)];
}

- (void) sendReadMemoryCommandWithAddress:(uint32_t)address length:(uint32_t)length readResult:(BOOL)readResult {
  uint8_t readMemCmd[] = {
    (address      ) & 0xff,
    (address >>  8) & 0xff,
    (address >> 16) & 0xff,
    (address >> 24) & 0xff,
    (length      ) & 0xff,
    (length >>  8) & 0xff,
    (length >> 16) & 0xff,
    (length >> 24) & 0xff,
  };
  
  int command;
  if (_romVersion < 0x00010002) {
    command = CommandReadMemory;
  }
  else {
    command = CommandReadPhysicalMemory;
  }
  
  [self sendRequestWithCommand:command body:&readMemCmd[0] length:sizeof(readMemCmd)];
  
  if (readResult == YES) {
    // Response length is: 1 (ResponseResult) + length + 1 (0x00)
    [self readDataForResponse:ResponseResult length:2 + length];
  }
}

- (void) sendReadMemoryCommandWithAddress:(uint32_t)address length:(uint32_t)length {
  [self sendReadMemoryCommandWithAddress:address length:length readResult:YES];
}

#pragma mark - Hardware Info helpers
- (NSString *) descriptionForManufacturer:(uint32_t)romManufacturer {
  switch (romManufacturer) {
    case 0x01000000:
      return @"Apple";
    case 0x10000100:
      return @"Sharp";
    case 0x01000200:
      return @"Motorola";
    default:
      return [NSString stringWithFormat:@"Unknown (%08x)", romManufacturer];
  }
}

- (NSString *) descriptionForHardwareType:(uint32_t)hardwareType
                         fromManufacturer:(uint32_t)manufacturer
{
  switch (hardwareType) {
    case 0x10002000:
      return @"Bic";
    case 0x10003000:
      return @"MessagePad 2000/2100 (Senior)";
    case 0x10004000:
      return @"eMate 300";
    case 0x10001000:
    {
      if (manufacturer == 0x01000200) {
        return @"ExpertPad";
      }
      else {
        return @"MessagePad (Junior)";
      }
    }
    case 0x00706120:
      return @"Siemens NotePhone";
    case 0x00726377:
    {
      if (manufacturer == 0x01000200) {
        return @"Marco";
      }
      else {
        return @"MessagePad 110/120/130 (Lindy)";
      }
    }
    default:
      return [NSString stringWithFormat:@"Unknown (%08x)", hardwareType];
  }
}

- (NSString *) descriptionForROMVersion:(uint32_t)romVersion {
  return [NSString stringWithFormat:@"v%i.%i", romVersion >> 16, romVersion & 0xffff];
}

- (uint32_t) determineROMSize {
  if (_romVersion < 0x00010002) {
    // On Junior hardware with 1.0.x and 1.1.x, when we attempt to
    // read 0x00400000, we only get back 2 bytes (3 with status): 0x5f20002.
    // I presume this is because we're using readMem instead of
    // readPhysMem (as the latter reboots the unit), and there is
    // some weird MMU mappings.
    // Hopefully there isn't Junior hardware with 8MB ROM - given
    // Lindy's first shipped with 4MB, this seems likely...
    return 4 * 1024 * 1024;
  }
  
  uint32_t *recvData = (uint32_t *)&_recvBuf[1];
  [self sendReadMemoryCommandWithAddress:0 length:4];
  uint32_t firstWord = recvData[0];
  
  uint32_t addr = 1024 * 1024;
  while (true) {
    [self sendReadMemoryCommandWithAddress:addr length:4];
    uint32_t thisWord = recvData[0];
    if (thisWord == firstWord) {
      break;
    }
    
    addr += 1024 * 1024;
    if (addr > 16 * 1024 * 1024) {
      NSLog(@"Exceeded 16MB. Giving up");
      addr = 0;
      break;
    }
  }
  return addr;
}

- (BOOL) retrieveHardwareInfo {
  uint32_t *recvData = (uint32_t *)&_recvBuf[1];
  
  // Read gROMManufacturer
  [self sendReadMemoryCommandWithAddress:0x000013f0 length:4];
  _romManufacturer = HTONL(recvData[0]);

  if (_useIntegrityChecks == YES) {
    switch (_romManufacturer) {
      case 0x01000000:
      case 0x10000100:
      case 0x01000200:
        break;
      default:
        return NO;
    }
  }

  // Read gHardwareType
  [self sendReadMemoryCommandWithAddress:0x000013ec length:4];
  _hardwareType = HTONL(recvData[0]);
  
  if (_useIntegrityChecks == YES) {
    switch (_hardwareType) {
      case 0x10002000:
      case 0x10003000:
      case 0x10004000:
      case 0x10001000:
      case 0x00726377:
        break;
      default:
        return NO;
    }
  }

  
  // Read gROMVersion
  [self sendReadMemoryCommandWithAddress:0x000013dc length:4];
  _romVersion = HTONL(recvData[0]);
  
  _romSize = [self determineROMSize];
  return YES;
}

#pragma mark - Initial handshaking
- (void) handleBisyncFrameHandshake {
  // Wait to receive an inquiry
  [self readDataForResponse:ResponseInquiry];
  
  // Send handshake
  [[self delegate] debuggerController:self updatedStatusMessage:NSLocalizedString(@"Handshaking...", @"Handshaking...")];
  uint8_t handshake[] = {0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x82, 0x00, 0x00};
  [self sendRequestWithCommand:CommandUnknown body:&handshake[0] length:sizeof(handshake)];
  
  // We expect two result frames
  [self readDataForResponse:ResponseResult];
  [self readDataForResponse:ResponseResult];
  
  // Followed by a stop with status frame
  [self readDataForResponse:ResponseStopWithStatus];
  
  // To which we send a STOP
  [self sendStopCommand];
  
  // Followed by another stop with status frame
  [self readDataForResponse:ResponseStopWithStatus];
}

- (void) handlePingPongHandshake {
  [[self delegate] debuggerController:self updatedStatusMessage:NSLocalizedString(@"Handshaking...", @"Handshaking...")];

  while (true) {
    if (_giveUp == true) {
      break;
    }
    
    [self sendRequestWithCommand:CommandPing];

    BOOL success = [self readDataForResponse:ResponsePong length:1];
    if (success == YES) {
      break;
    }
  }
}

- (void) handleHandshake {
  if ([self useBisyncFrames] == YES) {
    [self handleBisyncFrameHandshake];
  }
  else {
    [self handlePingPongHandshake];
  }
}

#pragma mark - ROM dumper
- (NSData *) dumpROMOfLength:(uint32_t)length {
  NSMutableData *romData = [[[NSMutableData alloc] initWithCapacity:length] autorelease];
  
  uint32_t *recvData = NULL;
  uint32_t addr = 0;
  
  id<DebuggerControllerDelegate> delegate = [self delegate];

  uint8_t readSize;
  if (_romVersion < 0x00020000) {
    // The v1.x devices seem happy sending all of the data
    // at once.
    [self sendReadMemoryCommandWithAddress:addr length:length readResult:NO];
    readSize = 128;
  }
  else {
    // The v2.x devices start sending a weird stream of 5f0000 when
    // we ask for too much memory. So we'll be conservative and slow...
    readSize = 12;
  }
  
  while (addr < length) {
    uint8_t chunkLength = readSize;
    if (_giveUp == true) {
      return nil;
    }
    
    if (_romVersion >= 0x00020000) {
      [self sendReadMemoryCommandWithAddress:addr length:readSize];
      // We're skipping the ResponseResult byte.
      recvData = (uint32_t *)&_recvBuf[1];
    }
    else {
      [self readResponseOfLength:readSize];
      int startIndex = 0;
      
      if (addr == 0x00) {
        // Our first chunk read, we need to find the
        // ResponseResult byte, and start copying data
        // after it.  Subsequent chunks won't have any
        // markers.
        while (_recvBuf[startIndex] != ResponseResult) {
          startIndex++;
          if (startIndex >= sizeof(_recvBuf)) {
            NSLog(@"Couldn't find ResponseResult marker");
            return nil;
          }
        }
        startIndex += 1;
        chunkLength -= startIndex;
      }

      recvData = (uint32_t *)&_recvBuf[startIndex];
    }
    
    [romData appendBytes:recvData length:chunkLength];
    addr += chunkLength;
    [delegate debuggerController:self updatedProgressValue:addr];
    readSize = MIN(readSize, length - addr);
  }
  
  return romData;
}

#pragma mark -
- (void) main {
  
  id<DebuggerControllerDelegate> delegate = [self delegate];
  [delegate debuggerControllerDidStart:self];
  [delegate debuggerController:self updatedStatusMessage:NSLocalizedString(@"Setting up serial port...", @"Setting up serial port...")];
  
  int speed;
  if (_useBisyncFrames == true) {
    speed = 57600;
  }
  else {
    speed = 19200;
  }
  _connection = [[NewtonConnection connectionWithDevicePath:[self devicePath] speed:speed] retain];
  
  // Wait for Newton to connect
  
  [delegate debuggerController:self updatedStatusMessage:NSLocalizedString(@"Waiting for Newton Debugger connection...", @"Waiting for Newton Debugger connection...")];
  
  if (_giveUp == true) {
    goto bail;
  }
  
  @try {
    [self handleHandshake];
    
    [delegate debuggerController:self updatedStatusMessage:NSLocalizedString(@"Detecting Newton type...", @"Detecting Newton type...")];
    BOOL success = [self retrieveHardwareInfo];
    if (success == NO) {
      [delegate debuggerControllerFailedIntegrityChecks:self];
      goto bail;
    }
    
    NSString *romVerison = [self descriptionForROMVersion:_romVersion];
    NSString *manufacturer = [self descriptionForManufacturer:_romManufacturer];
    NSString *hardwareType = [self descriptionForHardwareType:_hardwareType fromManufacturer:_romManufacturer];
    
    [delegate debuggerController:self retrievedROMVersion:romVerison];
    [delegate debuggerController:self retrievedManufacturer:manufacturer];
    [delegate debuggerController:self retrievedHardwareType:hardwareType];
    [delegate debuggerController:self retrievedROMSize:_romSize];

    if (_romSize > 0) {
      [delegate debuggerController:self updatedStatusMessage:NSLocalizedString(@"Downloading ROM", @"Downloading ROM")];
      NSData *romData = [self dumpROMOfLength:_romSize];
      if (romData != nil) {
        NSString *filename = [NSString stringWithFormat:@"%@ %@ %@.rom", manufacturer, hardwareType, romVerison];
        [delegate debuggerController:self downloadedROMData:romData proposedFileName:filename];
      }
    }

    [delegate debuggerController:self updatedStatusMessage:NSLocalizedString(@"Finished", @"Finished")];
  }
  @catch (id e) {
    NSLog(@"%s caught: %@", __PRETTY_FUNCTION__, e);
  }
  @finally {
    // Try to re-enable the Newton
    if (_romVersion >= 0x00020000) {
      [delegate debuggerController:self updatedStatusMessage:NSLocalizedString(@"Disconnecting", @"Disconnecting")];
      @try {
        [self sendGoCommand];
      }
      @catch (id e) {}
    }
  }
  
bail:
  
  [_connection cancel];
  [_connection release];
  _connection = nil;
  
  [delegate debuggerControllerDidFinish:self];
}

@end
