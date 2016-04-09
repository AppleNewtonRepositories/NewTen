//
//  PackageController.m
//  NewTen
//
//  Created by Steven Frank on ?/?/??.
//
//

#import "PackageController.h"

#import "AppDelegate.h"
#import "NewtonConnection.h"

//
// Based on UnixNPI by
// Richard C.I. Li, Chayim I. Kirshen, Victor Rehorst
// Objective-C adaptation by Steven Frank <stevenf@panic.com>
//

static unsigned char lrFrame[] =
{
  '\x17', // Length of header
  '\x01', // Type indication LR frame
  '\x02', // Constant parameter 1
  '\x01', '\x06', '\x01', '\x00', '\x00', '\x00', '\x00', '\xff', // Constant parameter 2
  '\x02', '\x01', '\x02', // Octet-oriented framing mode
  '\x03', '\x01', '\x01', // k = 1
  '\x04', '\x02', '\x40', '\x00', // N401 = 64
  '\x08', '\x01', '\x03' // N401 = 256 & fixed LT, LA frames
};


@implementation PackageController

- (void) dealloc {
  if (_packages) {
    [_packages release], _packages = nil;
  }
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
  giveUp = YES;
}

- (NSArray *) packages {
  return [[_packages retain] autorelease];
}

- (void) setPackages:(NSArray *)packages {
  if (_packages) {
    [_packages release], _packages = nil;
  }
  
  _packages = [packages retain];
}

- (NSString *) devicePath {
  return [[_devicePath retain] autorelease];
}

- (void) setDevicePath:(NSString *)devicePath {
  if (_devicePath) {
    [_devicePath release], _devicePath = nil;
  }
  
  _devicePath = [devicePath retain];
}

- (void) main
//
// Install the given packages
//
{ 
  FILE* inFile;
  long inFileLen;
  long tmpFileLen;
  unsigned char sendBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  unsigned char recvBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
  unsigned char ltSeqNo = 0;
  int i, j;
  int speed = 38400;
  BOOL success = NO;
  NSArray* packages = [self packages];
  NSString* devicePath = [self devicePath];
  
  giveUp = NO;
  
  AppDelegate *delegate = (id)[NSApp delegate];
  [delegate showStatusSheet];
  [delegate updateStatus:NSLocalizedString(@"Setting up serial port...", @"Setting up serial port...")];
  
  _connection = [[NewtonConnection connectionWithDevicePath:devicePath speed:speed] retain];
  
  // Wait for Newton to connect
  
  [delegate updateStatus:NSLocalizedString(@"Waiting for Newton Dock connection...", @"Waiting for Newton Dock connection...")];
  
  do
  {
    while ( [_connection receiveFrame:recvBuf] < 0 )
    {
      if ( giveUp )
        break;
    }
    
    if ( giveUp )
      break;
  }
  while ( recvBuf[1] != '\x01' );
  
  if ( giveUp )
    goto bail;

  [delegate updateStatus:NSLocalizedString(@"Handshaking...", @"Handshaking...")];
  
  // Send LR frame
  
  //	alarm(TimeOut);
  do
  {
    [_connection sendFrame:NULL header:lrFrame length:0];
  }
  while ( [_connection waitForLAFrame:ltSeqNo] < 0 && !giveUp );
		
  if ( giveUp )	
    goto bail;
		
  ++ltSeqNo;
  
  // Wait LT frame newtdockrtdk
  
  while ( [_connection receiveFrame:recvBuf] < 0 || recvBuf[1] != '\x04' )
  {
  }
  
  [_connection sendLAFrame:recvBuf[2]];
  
  // Send LT frame newtdockdock
  
  //	alarm(TimeOut);
  do
  {
    [_connection sendLTFrame:(unsigned char*)"newtdockdock\0\0\0\4\0\0\0\4" length:20 seqNo:ltSeqNo];
  }
  while ( [_connection waitForLAFrame:ltSeqNo] < 0 );
  
  ++ltSeqNo;
  
  // Wait LT frame newtdockname
  
  //	alarm(TimeOut);
  while ( (([_connection receiveFrame:recvBuf] < 0) || (recvBuf[1] != '\x04')) && !giveUp )
  {
  }
  
  if ( giveUp )
    goto bail;
  
  [_connection sendLAFrame:recvBuf[2]];
  
  // Get owner name
  
  i = recvBuf[19] * 256 * 256 * 256 + recvBuf[20] * 256 * 256 + recvBuf[21] *
  256 + recvBuf[22];
  
  i += 24;
  j = 0;
  
  while ( recvBuf[i] != '\0' )
  {
    sendBuf[j] = recvBuf[i];
    j++;
    i += 2;
  }
  sendBuf[j] = '\0';
  
  //NSLog([NSString stringWithCString:(char*)sendBuf]);
  
  // Send LT frame newtdockstim
  
  //	alarm(TimeOut);
  do
  {
    [_connection sendLTFrame:(unsigned char*)"newtdockstim\0\0\0\4\0\0\0\x1e" length:20 seqNo:ltSeqNo];
  }
  while ( [_connection waitForLAFrame:ltSeqNo] < 0 && !giveUp );
  
  if ( giveUp )
    goto bail;
  
  ++ltSeqNo;
  
  // Wait LT frame newtdockdres
  //	alarm(TimeOut);
  while( (([_connection receiveFrame:recvBuf] < 0) || (recvBuf[1] != '\x04')) && !giveUp )
  {
  }
  
  if ( giveUp )
    goto bail;
  
  [_connection sendLAFrame:recvBuf[2]];
  
  // batch install all of the files
  
  NSEnumerator* enumerator = [packages objectEnumerator];
  NSString* package;
  
  while ( (package = [enumerator nextObject]) )
  {
    if ( (inFile = fopen([package fileSystemRepresentation], "rb")) == NULL )
    {
      //ErrHandler("Error in opening package file!!");
      goto bail;
    }
    
    fseek(inFile, 0, SEEK_END);
    inFileLen = ftell(inFile);
    rewind(inFile);
    
    //printf("File is '%s'\n", argv[k]);
    
    // Send LT frame newtdocklpkg
    //		alarm(TimeOut);
    
    strcpy((char*)sendBuf, "newtdocklpkg");
    tmpFileLen = inFileLen;
    for ( i = 15; i >= 12; i-- )
    {
      sendBuf[i] = tmpFileLen % 256;
      tmpFileLen /= 256;
    }
    
    do
    {
      [_connection sendLTFrame:sendBuf length:16 seqNo:ltSeqNo];
    }
    while ( [_connection waitForLAFrame:ltSeqNo] < 0 && !giveUp );
    
    if ( giveUp )
      goto bail;
    
    ++ltSeqNo;
    
    [delegate updateStatus:NSLocalizedString(@"Installing package...", @"Installing package...")];
    [delegate updateProgressMax:[NSNumber numberWithInt:inFileLen]];
    
    // Send package data
    
    while ( !feof(inFile) )
    {
      //			alarm(TimeOut);
      
      i = fread(sendBuf, sizeof(unsigned char), MAX_INFO_LEN, inFile);
      
      while ( i % 4 != 0 )
        sendBuf[i++] = '\0';
      
      do
      {
        [_connection sendLTFrame:sendBuf length:i seqNo:ltSeqNo];
      }
      while ( [_connection waitForLAFrame:ltSeqNo] < 0 && !giveUp );
      
      if ( giveUp )
        goto bail;
      
      ++ltSeqNo;
      
      if ( ltSeqNo % 4 == 0 )
      {
        [delegate updateProgress:[NSNumber numberWithInt:ftell(inFile)]];
      }
    }
    
    [delegate updateProgress:[NSNumber numberWithInt:inFileLen]];
    
    // Wait LT frame newtdockdres
    //		alarm(TimeOut);
    
    while ( (([_connection receiveFrame:recvBuf] < 0) || (recvBuf[1] != '\x04')) && !giveUp )
    {
    }
    
    if ( giveUp )
      goto bail;
    
    [_connection sendLAFrame:recvBuf[2]];
    
    fclose(inFile);
  }
  
  // Send LT frame newtdockdisc
  //	alarm(TimeOut);
  do
  {
    [_connection sendLTFrame:(unsigned char*)"newtdockdisc\0\0\0\0" length:16 seqNo:ltSeqNo];
  }
  while ( [_connection waitForLAFrame:ltSeqNo] < 0 && !giveUp );
  
  if ( giveUp )
    goto bail;
  
  // Wait disconnect
  //	alarm(0);
  [_connection waitForLDFrame];
  
  [delegate updateStatus:NSLocalizedString(@"Finished", @"Finished")];
  
  success = YES;
  
bail:
  
  if ( giveUp )
    [_connection disconnect];
  
  [_connection release];
  _connection = nil;
  
  [delegate hideStatusSheet];
}

/*
 - (void)timeout:(NSTimer*)timer
 {
 NSLog(@"timed out");
 NewtonConnection* connection = [timer userInfo];
 [connection cancel];
 
 giveUp = YES;
 }
 */

@end

