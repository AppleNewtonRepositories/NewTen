//
//  AppDelegate.m
//  NewTen
//
//  Created by Steven Frank on ?/?/??.
//
//

#import "AppDelegate.h"

#import "PackageController.h"
#import "DebuggerController.h"
#import "DownloadWindowController.h"

@interface NSObject(ControllerMethods)
- (void) main;
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
//
// Quit if window closed
//
{
  return YES;
}


- (void)awakeFromNib
//
// Things to do on launch
//
{
  [self scanForSerialDrivers:self];
  
  NSString* preferredPort = [[NSUserDefaults standardUserDefaults] objectForKey:@"PreferredPort"];
  
  if ( preferredPort )
  {
    if ( preferredPort != nil )
    {
      int index = [driverButton indexOfItemWithRepresentedObject:preferredPort];
      
      if ( index == - 1 )
        index = 0;
      
      [driverButton selectItemAtIndex:index];
    }
  }
  
  [self selectDriver:self];
  [mainWindow setFrameAutosaveName:@"MainWindow"];
  
  [mainWindow registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

#pragma mark -
- (void) setActiveController:(id)controller {
  if (_activeController != nil) {
    [_activeController cancel];
    [_activeController release];
    _activeController = nil;
  }
  
  _activeController = [controller retain];
}

- (id) activeController {
  return [[_activeController retain] autorelease];
}

#pragma mark - Serial helpers
- (void)scanForSerialDrivers:(id)sender
//
// Add any item matching cu.* or tty.* from /dev to the
// serial driver popup menu
//
{
  DIR* dir;
  struct dirent* ent;
  
  // Remove all existing menu items except the "None" item
  
  while ( [driverButton numberOfItems] > 1 )
    [driverButton removeItemAtIndex:1];
		
  // Walk through /dev, looking for either cu.* or tty.* items
  
  if ( (dir = opendir("/dev")) )
  {
    while ( (ent = readdir(dir)) )
    {
      // Device name must be at least 4 characters long to
      // do the following string comparisons..
      
      if ( ent->d_namlen >= 4 )
      {
        if ( (strncmp(ent->d_name, "cu.", 3) == 0) )
        {
          // Add item to serial driver menu
          
          if ( strcmp(ent->d_name, "cu.modem") == 0 )
          {
            // Built-in, GeeThree, or similar
            
            [driverButton addItemWithTitle:@"Built-In Serial"];
          }
          else if ( strncmp(ent->d_name, "cu.USA28X", 9) == 0
                   || strncmp(ent->d_name, "cu.KeySerial", 12) == 0 )
          {
            // Some sort of KeySpan driver
            
            int len = strlen(ent->d_name);
            
            if ( ent->d_name[len - 1] == '1' )
              [driverButton addItemWithTitle:@"KeySpan Port 1"];
            
            else if ( ent->d_name[len - 1] == '2' )
              [driverButton addItemWithTitle:@"KeySpan Port 2"];
            
            else
              [driverButton addItemWithTitle:@"Unknown KeySpan Port"];
          }
          else if ( strncmp(ent->d_name, "cu.usbserial", 12) == 0 )
          {
            // NewtUSB
            
            [driverButton addItemWithTitle:@"NewtUSB"];
          }
          else if ( strcmp(ent->d_name, "cu.Bluetooth-PDA-Sync") == 0
                   || strcmp(ent->d_name, "cu.Bluetooth-Modem") == 0 )
          {
            // Hide these, they won't work
            
            continue;
          }
          else
          {
            // Don't know what this is, just show the raw device name
            
            [driverButton addItemWithTitle:[NSString stringWithCString:ent->d_name]];
          }
          
          // Associate device name with this menu item
          
          [[driverButton lastItem] setRepresentedObject:[NSString stringWithCString:ent->d_name]];
        }
      }
      
    }
    
    closedir(dir);
  }
}

- (NSString *) devicePath {
  NSMenuItem* item = [driverButton itemAtIndex:[driverButton indexOfSelectedItem]];
  NSString* devicePath = [NSString stringWithFormat:@"/dev/%s",
                          [[item representedObject] fileSystemRepresentation]];
  return devicePath;
}

#pragma mark - Thread helper
- (void) startThreadForController:(id)controller {
	[self setActiveController:controller];
	[NSThread detachNewThreadSelector:@selector(activeControllerThread) toTarget:self withObject:nil];
}

- (void) activeControllerThread {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	id controller = [self activeController];
	[controller main];
	
	[pool drain];
	[self performSelectorOnMainThread:@selector(finishThreadForActiveController) withObject:nil waitUntilDone:NO];
}

- (void) finishThreadForActiveController {
	[self setActiveController:nil];
}

#pragma mark - Packages
- (void) installPackages:(NSArray *)packages runAsModal:(BOOL)runAsModal {
  runSheetAsModal = runAsModal;
  
  PackageController *pkgController = [[PackageController alloc] init];
  [pkgController setPackages: packages];
  [pkgController setDevicePath: [self devicePath]];
  [self startThreadForController:pkgController];
  [pkgController release];
}

- (void) installPackages:(NSArray *)packages
{
  [self installPackages:packages runAsModal:NO];
}

- (void)packagePanelDidEnd:(NSOpenPanel*)inSheet
                returnCode:(int)returnCode
               contextInfo:(void*)contextInfo
//
// Called when open panel closes
//
{
	if ( returnCode == NSOKButton )
	{
		// Get selected files
		
		NSArray* packages = [inSheet filenames];
		
		// Close sheet
		
		[inSheet orderOut:self];
		
		// Install selected packages
		[self installPackages:packages];
	}
}

#pragma mark - Drag 'n Drop
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
//
// We accept all file drags
//
{
  return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
//
// Called upon file drop
//
{
  NSPasteboard* pb = [sender draggingPasteboard];
  
  // Make sure pasteboard has filenames on it, otherwise bail
  
  if ( ![[pb types] containsObject:NSFilenamesPboardType] )
    return NO;
		
  // Get filename array, and start installing
  
  NSArray* packages = [pb propertyListForType:NSFilenamesPboardType];
  
  [self installPackages:packages];
  return YES;
}

#pragma mark - Download helpers
- (void)downloadSheetDidEnd:(NSOpenPanel*)inSheet
                 returnCode:(int)returnCode
                contextInfo:(void*)contextInfo
{
  [[downloadController window] orderOut:nil];
  downloadController = nil;
}

#pragma mark - Actions
- (IBAction)downloadROM:(id)sender {
  if (downloadController == nil) {
    downloadController = [[DownloadWindowController alloc] init];
  }
  
  NSWindow *downloadSheet = downloadController.window;
  
  [NSApp beginSheet:downloadSheet
     modalForWindow:mainWindow
      modalDelegate:self
     didEndSelector:@selector(downloadSheetDidEnd:returnCode:contextInfo:)
        contextInfo:nil];
}

- (IBAction)selectPackage:(id)sender
//
// Called when user clicks on the button to select which package should
// be installed
//
{
  NSArray* fileTypes = [NSArray arrayWithObjects:@"pkg", @"PKG", @"Pkg", nil];
  
  // Display an "open file" sheet
  
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setAllowsMultipleSelection:YES];
  
  [openPanel beginSheetForDirectory:nil
                               file:nil
                              types:fileTypes
                     modalForWindow:mainWindow
                      modalDelegate:self
                     didEndSelector:@selector(packagePanelDidEnd:returnCode:contextInfo:)
                        contextInfo:self];
}

- (IBAction)selectDriver:(id)sender
//
// Called when user selects an item from serial driver popup menu
//
{
  // If serial driver selected is not the "None" item,
  // then enable the "Install Package" button
  
  BOOL enabled = ([driverButton indexOfSelectedItem] != 0);
  [installPackageButton setEnabled:enabled];
  [downloadRomButton setEnabled:enabled];
  
  if ( enabled )
  {
    [[NSUserDefaults standardUserDefaults] 
     setObject:[[driverButton itemAtIndex:[driverButton indexOfSelectedItem]] 
                representedObject] forKey:@"PreferredPort"];
  }
  else
  {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PreferredPort"];
  }
  
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)showHelp:(id)sender
//
// User selected help menu item
//
{
  NSString* readMePath = [[NSBundle mainBundle] pathForResource:@"Instructions" ofType:@"rtf"];
  [[NSWorkspace sharedWorkspace] openFile:readMePath];
}

- (IBAction)cancelInstall:(id)sender
{
  [_activeController cancel];
}


- (IBAction)installPackage:(id)sender
//
// Called when "Install Package" clicked
//
{
  [self selectPackage:sender];
//  [NSApp beginSheet:sheet modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

#pragma mark - Progress helpers
- (void)hideStatusSheet
{
  if ([NSThread isMainThread] == NO) {
    return [self performSelectorOnMainThread:_cmd
                                  withObject:nil
                               waitUntilDone:NO];
  }

  if (runSheetAsModal == YES) {
    [NSApp stopModal];
  }
  else {
    [NSApp endSheet:sheet];
    [sheet orderOut:self];
  }
}

- (void)showStatusSheet
{
  if ([NSThread isMainThread] == NO) {
    return [self performSelectorOnMainThread:_cmd
                                  withObject:nil
                               waitUntilDone:NO];
  }

  [self updateProgress:[NSNumber numberWithInt:0]];
  [self updateProgressMax:[NSNumber numberWithInt:100]];

  if (runSheetAsModal == YES) {
    [NSApp runModalForWindow:sheet];
    [sheet orderOut:nil];
  }
  else {
    [NSApp beginSheet:sheet modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
  }
}

- (void)updateProgress:(NSNumber*)current
//
// Update the installation progress bar
//
{
  if ([NSThread isMainThread] == NO) {
    return [self performSelectorOnMainThread:_cmd
                                  withObject:current
                               waitUntilDone:NO];
  }

  [progress setDoubleValue:[current doubleValue]];
}


- (void)updateProgressMax:(NSNumber*)maximum
//
// Update the installation progress bar
//
{
  if ([NSThread isMainThread] == NO) {
    return [self performSelectorOnMainThread:_cmd
                                  withObject:maximum
                               waitUntilDone:NO];
  }

  [progress setMinValue:0];
  [progress setMaxValue:[maximum doubleValue]];
}


- (void)updateStatus:(NSString*)statusText
//
// Update the installation status text
//
{
  if ([NSThread isMainThread] == NO) {
    return [self performSelectorOnMainThread:_cmd
                                  withObject:statusText
                               waitUntilDone:NO];
  }

  [status setStringValue:statusText];
}

@end
