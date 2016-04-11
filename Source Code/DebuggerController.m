//
//  DebuggerController.m
//  NewTen
//
//  Created by Steve White on 4/8/16.
//
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

- (AppDelegate *) delegate {
  return (id)[NSApp delegate];
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
- (void) sendFrameWithCommand:(uint8_t)command body:(uint8_t *)body length:(uint8_t)length {
  memset(_sendBuf, 0x00, sizeof(_sendBuf));
  _sendBuf[0] = command;
  
  if (length > 0) {
    if (length - 1 > sizeof(_sendBuf)) {
      NSLog(@"Length would exceed _sendBuf size. truncating!");
      length = (uint8_t)sizeof(_sendBuf) - 1;
    }
    memcpy(&_sendBuf[1], body, length);
  }
  
  [_connection sendFrame:&_sendBuf[0] header:NULL length:length + 1];
  if (_giveUp == true) {
    [[NSException exceptionWithName:@"DebuggerControllerCancelled" reason:@"_giveUp == true" userInfo:nil] raise];
  }
}

- (void) sendFrameWithCommand:(uint8_t)command {
  [self sendFrameWithCommand:command body:NULL length:0];
}

- (void) sendCloseCommand {
  [self sendFrameWithCommand:CommandClose];
}

- (void) sendGoCommand {
  [self sendFrameWithCommand:CommandAck];
  
  uint8_t goCommand[] = { 0x00, 0x00, 0x00, 0x00 };
  [self sendFrameWithCommand:CommandGo body:&goCommand[0] length:sizeof(goCommand)];
  [self readDataForResponse:ResponseResult];
  /*
   uint8_t execCommand[] = { 0x10, 0x01 };
   [self sendFrameWithCommand:CommandExecute body:&execCommand[0] length:sizeof(execCommand)];
   [self readDataForResponse:ResponseResult];
   */
}

- (void) sendStopCommand {
  uint8_t stopCmd[] = { 'S', 'T', 'O', 'P'};
  [self sendFrameWithCommand:CommandStop body:&stopCmd[0] length:sizeof(stopCmd)];
}

- (void) sendReadMemoryCommandWithAddress:(uint32_t)address length:(uint32_t)length {
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
  
  [self sendFrameWithCommand:CommandReadPhysicalMemory body:&readMemCmd[0] length:sizeof(readMemCmd)];
  [self readDataForResponse:ResponseResult];
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

- (NSString *) deviceDescription {
  uint32_t *recvData = (uint32_t *)&_recvBuf[1];
  
  // Read gROMManufacturer
  [self sendReadMemoryCommandWithAddress:0x000013f0 length:4];
  _romManufacturer = HTONL(recvData[0]);
  
  // Read gHardwareType
  [self sendReadMemoryCommandWithAddress:0x000013ec length:4];
  _hardwareType = HTONL(recvData[0]);
  
  // Read gROMVersion
  [self sendReadMemoryCommandWithAddress:0x000013dc length:4];
  _romVersion = HTONL(recvData[0]);
  
  NSArray *components = @[
                          [self descriptionForManufacturer:_romManufacturer],
                          [self descriptionForHardwareType:_hardwareType fromManufacturer:_romManufacturer],
                          [self descriptionForROMVersion:_romVersion],
                          ];
  
  NSString *hardwareInfo = [components componentsJoinedByString:@" "];
  return hardwareInfo;
}

- (void) handleHandshake {
  // Wait to receive an inquiry
  [self readDataForResponse:ResponseInquiry];
  
  // Send handshake
  [[self delegate] updateStatus:NSLocalizedString(@"Handshaking...", @"Handshaking...")];
  uint8_t handshake[] = {0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x82, 0x00, 0x00};
  [self sendFrameWithCommand:CommandUnknown body:&handshake[0] length:sizeof(handshake)];
  
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

- (uint32_t) determineROMSize {
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

- (NSData *) dumpROMOfLength:(uint32_t)length {
  NSMutableData *romData = [[[NSMutableData alloc] initWithCapacity:length] autorelease];
  
  uint32_t *recvData = (uint32_t *)&_recvBuf[1];
  uint32_t addr = 0;
  
  AppDelegate *delegate = [self delegate];
  [delegate updateProgressMax:[NSNumber numberWithInt:length]];
  
#define READ_SIZE 12
  while (addr < length) {
    [self sendReadMemoryCommandWithAddress:addr length:READ_SIZE];
    
    [romData appendBytes:recvData length:READ_SIZE];
    addr += READ_SIZE;
    [delegate updateProgress:[NSNumber numberWithInt:addr]];
  }
  
  return romData;
}

#pragma mark -
- (void) main {
  
  AppDelegate *delegate = [self delegate];
  [delegate showStatusSheet];
  [delegate updateStatus:NSLocalizedString(@"Setting up serial port...", @"Setting up serial port...")];
  
  int speed;
  if (_useBisyncFrames == true) {
    speed = 57600;
  }
  else {
    speed = 19200;
  }
  _connection = [[NewtonConnection connectionWithDevicePath:[self devicePath] speed:speed] retain];
  
  // Wait for Newton to connect
  
  [delegate updateStatus:NSLocalizedString(@"Waiting for Newton Debugger connection...", @"Waiting for Newton Debugger connection...")];
  
  if (_giveUp == true) {
    goto bail;
  }
  
  @try {
    [self handleHandshake];
    
    [delegate updateStatus:NSLocalizedString(@"Detecting Newton type...", @"Detecting Newton type...")];
    NSString *deviceDescription = [self deviceDescription];
    [delegate updateStatus:deviceDescription];
    
    uint32_t romSize = [self determineROMSize];
    if (romSize > 0) {
      NSString *humanSize = [NSString stringWithFormat:@" (%i MB)", romSize / 1024 / 1024];
      deviceDescription = [deviceDescription stringByAppendingString:humanSize];
      [delegate updateStatus:deviceDescription];
      
      NSData *romData = [self dumpROMOfLength:romSize];
      if (romData != nil) {
        [delegate saveData:romData withFilename:[deviceDescription stringByAppendingPathExtension:@"rom"]];
      }
    }
    [delegate updateStatus:NSLocalizedString(@"Finished", @"Finished")];
  }
  @catch (id e) {
    NSLog(@"%s caught: %@", __PRETTY_FUNCTION__, e);
  }
  @finally {
    // Try to re-enable the Newton
    if (_romVersion >= 0x00020000) {
      [delegate updateStatus:NSLocalizedString(@"Disconnecting", @"Disconnecting")];
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
  
  [delegate hideStatusSheet];
}

@end
