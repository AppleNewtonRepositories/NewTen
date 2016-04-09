//
//  PackageController.h
//  NewTen
//
//  Created by Steven Frank on ?/?/??.
//
//

@class NewtonConnection;

@interface PackageController : NSObject
{	
	NewtonConnection* _connection;
	volatile BOOL giveUp;
  
  NSArray* _packages;
  NSString* _devicePath;
}

- (NSArray *) packages;
- (void) setPackages:(NSArray *)packages;

- (NSString *) devicePath;
- (void) setDevicePath:(NSString *)devicePath;

@end
