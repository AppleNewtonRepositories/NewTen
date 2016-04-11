#define MAX_HEAD_LEN 256
#define MAX_INFO_LEN 256

@interface NewtonConnection : NSObject 
{
	unsigned char frameStart[3];
	unsigned char frameEnd[2];
	unsigned char ldFrame[5]; 
	int newtFD;
	struct termios newtTTY;
	BOOL canceled;
}

+ (NewtonConnection*)connectionWithDevicePath:(NSString*)devicePath speed:(int)speed;

- (void)cancel;
- (void)disconnect;

- (BOOL)sendData:(unsigned char *)data length:(int *)length;
- (int)readData:(unsigned char *)buf length:(int)length;

- (int)receiveFrame:(unsigned char*)frame length:(int *)length;
- (int)receiveFrame:(unsigned char*)frame;

- (BOOL)sendFrame:(unsigned char*)info header:(unsigned char*)head length:(int)infoLen;

- (void)sendLAFrame:(unsigned char)seqNo;
- (void)sendLTFrame:(unsigned char*)info length:(int)infoLen seqNo:(unsigned char)seqNo;

- (int)waitForLAFrame:(unsigned char)seqNo;
- (int)waitForLDFrame;

@end
