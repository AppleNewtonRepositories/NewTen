//
//  AppDelegate.h
//  NewTen
//
//  Created by Steven Frank on ?/?/??.
//
//

#import <AppKit/AppKit.h>

@class DownloadWindowController;

@interface AppDelegate : NSObject {
  IBOutlet NSPopUpButton* driverButton;
  IBOutlet NSButton* installPackageButton;
  IBOutlet NSButton* downloadRomButton;
  IBOutlet NSWindow* mainWindow;
  IBOutlet NSProgressIndicator* progress;
  IBOutlet NSTextField* status;
  IBOutlet NSPanel* sheet;
  
  DownloadWindowController *downloadController;
  
  id _activeController;
}

- (IBAction)installPackage:(id)sender;
- (IBAction)scanForSerialDrivers:(id)sender;
- (IBAction)selectDriver:(id)sender;
- (IBAction)selectPackage:(id)sender;
- (IBAction)downloadROM:(id)sender;

- (NSString *)devicePath;

- (void) setActiveController:(id)controller;
- (id) activeController;
- (void) startThreadForController:(id)controller;

- (void)showStatusSheet;
- (void)hideStatusSheet;
- (void)updateProgress:(NSNumber*)current;
- (void)updateProgressMax:(NSNumber*)maximum;
- (void)updateStatus:(NSString*)statusText;

@end
