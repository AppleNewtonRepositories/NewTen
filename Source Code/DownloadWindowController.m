//
//  DownloadWindowController.m
//  NewTen
//
//  Created by Steve White on 4/11/16.
//
//

#import "DownloadWindowController.h"

#import "AppDelegate.h"
#import "ScreencastView.h"
#import "TableOfContentsView.h"

@implementation DownloadWindowController

@synthesize steps = _steps;
@synthesize stepIndex = _stepIndex;
@synthesize autoplayTimer = _autoplayTimer;
@dynamic autoplaying;

+ (NSSet *) keyPathsForValuesAffectingAutoplaying {
  return [NSSet setWithObject:@"autoplayTimer"];
}

+ (NSSet *) keyPathsForValuesAffectingPlayPauseButtonImage {
  return [NSSet setWithObject:@"autoplayTimer"];
}

- (id) init {
  return [self initWithWindowNibName:@"ROMDownload"];
}

- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)windowDidLoad {
  [super windowDidLoad];
  
  [self switchContentViewForTabViewItem:[tabView selectedTabViewItem]];
  [self _startAutoplayTimer];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(urlClickedNotification:)
                                               name:TableOfContentsViewURLClickedNotification
                                             object:nil];
}

- (void) close {
  [super close];
  [self _stopAutoplayTimer];
}

#pragma mark -
- (BOOL) isOldNewtonSelected {
  return ([[[tabView selectedTabViewItem] identifier] intValue] == 1);
}

#pragma mark - Resizing
- (void) layoutContentView {
#define ContentFrameInset 20
  
  // Figure out the width of the screencast, so we
  // can center the buttons under it
  NSSize screencastSize = [screencast contentSize];
  NSRect screencastFrame = NSZeroRect;
  screencastFrame.origin.x = ContentFrameInset;
  screencastFrame.size = screencastSize;
  
  // Layout the screencast buttons
  NSRect screencastButtonsFrame = screencastButtons.frame;
  screencastButtonsFrame.origin.y = 8;
  screencastButtonsFrame.origin.x = screencastFrame.origin.x + floorf((screencastFrame.size.width - screencastButtonsFrame.size.width) / 2);
  
  // Now that they're laid out, we can move the screencast into
  // y position.
  screencastFrame.origin.y = NSMaxY(screencastButtonsFrame) + 8;
  
  // We'll keep the TOC the same height as the screencast,
  NSSize tocSize = toc.bounds.size;
  NSRect tocFrame = toc.frame;
  tocFrame.origin.x = NSMaxX(screencastFrame) + 18;
  tocFrame.origin.y = NSMinY(screencastFrame);
  tocFrame.size.width = tocSize.width;
  tocFrame.size.height = screencastFrame.size.height;
  
  // Align the right of the download button to the right of the TOC
  NSRect downloadFrame = downloadButton.frame;
  downloadFrame.origin.x = (NSMaxX(tocFrame) - downloadFrame.size.width) + 6;
  downloadFrame.origin.y = 2;
  
  NSRect closeFrame = closeButton.frame;
  closeFrame.origin.x = NSMinX(downloadFrame) - 4 - closeFrame.size.width;
  closeFrame.origin.y = downloadFrame.origin.y;
  
  NSRect contentFrame = NSZeroRect;
  contentFrame.size.width = NSMaxX(tocFrame) + ContentFrameInset;
  contentFrame.size.height = MAX(NSMaxX(screencastButtonsFrame), NSMaxY(tocFrame)) + ContentFrameInset;
  
  contentView.frame = contentFrame;
  screencast.frame = screencastFrame;
  screencastButtons.frame = screencastButtonsFrame;
  downloadButton.frame = downloadFrame;
  closeButton.frame = closeFrame;
  toc.frame = tocFrame;
}

- (void) resizeWindow {
  NSSize contentSize = contentView.bounds.size;
  // Add padding for the NSTabView..
  contentSize.width += 40;
  contentSize.height += 70;
  NSRect frame = self.window.frame;
  frame.origin.y -= contentSize.height - frame.size.height;
  frame.size = contentSize;
  [self.window setFrame:frame display:YES];
}

- (void) switchContentViewForTabViewItem:(NSTabViewItem *)tabViewItem {
  NSString *scriptName = nil;
  
  if ([self isOldNewtonSelected] == YES) {
    scriptName = @"nos1-setup-script";
  }
  else {
    scriptName = @"nos2-setup-script";
  }
  
  [self loadScriptNamed:scriptName];
  
  [contentView removeFromSuperview];
  [tabViewItem.view addSubview:contentView];
  
  [self layoutContentView];
  [self resizeWindow];
  
  self.stepIndex = 0;
  [self renderStepAtIndex:self.stepIndex];
  [self _restartAutoplayTimerIfNecessary];
}

#pragma mark - NSTabView delegate
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
  [self switchContentViewForTabViewItem:tabViewItem];
}

#pragma mark - Timer
- (void) _startAutoplayTimer {
  if (self.autoplayTimer != nil) {
    return;
  }
  
  NSTimer *autoplayTimer = [NSTimer timerWithTimeInterval:3.0
                                                   target:self
                                                 selector:@selector(autoplayTimerFired:)
                                                 userInfo:nil
                                                  repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:autoplayTimer forMode:NSRunLoopCommonModes];
  self.autoplayTimer = autoplayTimer;
}

- (void) _stopAutoplayTimer {
  if (self.autoplayTimer != nil) {
    [self.autoplayTimer invalidate];
    self.autoplayTimer = nil;
  }
}

- (void) _restartAutoplayTimerIfNecessary {
  if (self.isAutoplaying) {
    [self _stopAutoplayTimer];
    [self _startAutoplayTimer];
  }
}

- (void) autoplayTimerFired:(NSTimer *)timer {
  [self renderNextStep:self];
}

- (BOOL) isAutoplaying {
  return (self.autoplayTimer != nil);
}

- (NSImage *) playPauseButtonImage {
  NSString *imageName = nil;
  if (self.autoplaying) {
    imageName = @"PauseQTPrivateTemplate";
  }
  else {
    imageName = @"PlayTemplate";
  }
  return [NSImage imageNamed:imageName];
}

#pragma mark - Step rendering
- (void) renderStepAtIndex:(NSInteger)index {
  NSArray *imageIdentifiers = [screencast allIdentifiers];
  for (NSString *anImageIdentifier in imageIdentifiers) {
    [screencast setHidden:YES forImageWithIdentifier:anImageIdentifier];
  }
  
	NSDictionary *step = [self.steps objectAtIndex:index];
	NSArray *visibleImages = [step objectForKey:@"visibleImages"];
  for (NSString *anImageIdentifier in visibleImages) {
    [screencast setHidden:NO forImageWithIdentifier:anImageIdentifier];
  }
  
  NSRect highlightRect = NSZeroRect;
	NSString *highlightRectStr = [step objectForKey:@"highlightRect"];
  if (highlightRectStr != nil) {
    highlightRect = NSRectFromString(highlightRectStr);
  }
  
  [screencast highlightRect:highlightRect];
  
  toc.selectedTitleIndex = index;
  self.stepIndex = index;
}

#pragma mark - Script loading
- (id) processedTextFromString:(NSString *)string {
  NSRange linkTextStartRange = [string rangeOfString:@"["];
  if (linkTextStartRange.location == NSNotFound) {
    return string;
  }
  
  NSRange remainingRange;
  remainingRange.location = NSMaxRange(linkTextStartRange);
  remainingRange.length = [string length] - remainingRange.location;
  NSRange linkTextEndRange = [string rangeOfString:@"]" options:0 range:remainingRange];
  if (linkTextEndRange.location == NSNotFound) {
    return string;
  }

  NSRange linkTextRange;
  linkTextRange.location = NSMaxRange(linkTextStartRange);
  linkTextRange.length = linkTextEndRange.location - linkTextRange.location;
  
  if ([string characterAtIndex:NSMaxRange(linkTextEndRange)] != '(') {
    return string;
  }
  
  remainingRange.location = NSMaxRange(linkTextEndRange) + 2;
  remainingRange.length = [string length] - remainingRange.location;

  NSRange linkEndRange = [string rangeOfString:@")" options:0 range:remainingRange];
  if (linkEndRange.location == NSNotFound) {
    return string;
  }

  NSRange linkRange;
  linkRange.location = NSMaxRange(linkTextEndRange) + 1;
  linkRange.length = linkEndRange.location - linkRange.location;
  
  NSString *prefix = [string substringToIndex:linkTextStartRange.location];
  NSString *suffix = [string substringFromIndex:NSMaxRange(linkEndRange)];
  NSString *linkText = [string substringWithRange:linkTextRange];
  NSString *link = [string substringWithRange:linkRange];
  
  NSDictionary *linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                  link, NSLinkAttributeName,
                                  [NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
                                  [NSColor blueColor], NSForegroundColorAttributeName,
                                  nil];
  
  NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
  [result appendAttributedString:[[[NSAttributedString alloc] initWithString:prefix attributes:nil] autorelease]];
  [result appendAttributedString:[[[NSAttributedString alloc] initWithString:linkText attributes:linkAttributes] autorelease]];
  [result appendAttributedString:[[[NSAttributedString alloc] initWithString:suffix attributes:nil] autorelease]];
  return result;
}

- (void) loadScriptNamed:(NSString *)scriptName {
  [screencast removeAllImages];
  
  NSDictionary *script = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:scriptName ofType:@"plist"]];
  if (script == nil) {
    NSLog(@"%s couldn't load script named: %@", __PRETTY_FUNCTION__, scriptName);
    return;
  }
  
  NSArray *assets = [script objectForKey:@"assets"];
  for (NSDictionary *anAsset in assets) {
    NSString *identifier = [anAsset objectForKey:@"identifier"];
    NSString *imageName = [anAsset objectForKey:@"imageName"];
    NSPoint point = NSPointFromString([anAsset objectForKey:@"point"]);
    
    if (identifier == nil || imageName == nil) {
      NSLog(@"%s can't create asset with nil identifier/imageName: %@", __PRETTY_FUNCTION__, anAsset);
    }
    else {
      [screencast addImageNamed:imageName atPoint:point withIdentifier:identifier];
    }
  }
  
  NSArray *steps = [script objectForKey:@"steps"];
  NSMutableArray *stepTitles = [NSMutableArray array];
  for (NSDictionary *aStep in steps) {
    NSString *stepTitle = [aStep objectForKey:@"title"];
    if (stepTitle == nil) {
      NSLog(@"%s can't process step without a title: %@", __PRETTY_FUNCTION__, aStep);
    }
    else {
      [stepTitles addObject:[self processedTextFromString:stepTitle]];
    }
  }
  
  toc.titles = stepTitles;
  self.steps = steps;
}

#pragma mark - Actions
- (IBAction)dismiss:(id)sender {
  if ([self.window isSheet] == YES) {
    [NSApp endSheet:[self window]];
  }
  else {
    [self.window close];
  }
}

- (IBAction)download:(id)sender {
  [self _stopAutoplayTimer];

  AppDelegate *appDelegate = (id)[NSApp delegate];

  _debugController = [[DebuggerController alloc] init];
  [_debugController setDevicePath:[appDelegate devicePath]];
  [_debugController setDelegate:self];
  if ([self isOldNewtonSelected] == NO) {
    _debugController.useBisyncFrames = YES;
  }
  [appDelegate startThreadForController:_debugController];
}

- (IBAction)cancel:(id)sender {
  NSInteger result = NSRunAlertPanel(NSLocalizedString(@"Stop Download?", @"Stop Download?"),
                                     NSLocalizedString(@"If you stop the download, you will have to reboot your Newton.", @"If you stop the download, you will have to reboot your Newton."),
                                     NSLocalizedString(@"Continue Download", @"Continue Download"),
                                     NSLocalizedString(@"Stop Download", @"Stop Download"),
                                     nil);
  if (result == 0) {
    [_debugController cancel];
  }
}

- (IBAction)toggleAutoplayTimer:(id)sender {
  if (self.autoplaying) {
    [self _stopAutoplayTimer];
  }
  else {
    [self _startAutoplayTimer];
  }
}

- (IBAction)renderNextStep:(id)sender {
  NSInteger index = self.stepIndex + 1;
  if (index >= [self.steps count]) {
    index = 0;
  }
  
  [self renderStepAtIndex:index];
  [self _restartAutoplayTimerIfNecessary];
}

- (IBAction)renderPreviousStep:(id)sender {
  NSInteger index = self.stepIndex - 1;
  if (index < 0) {
    index = [self.steps count] - 1;
  }
  
  [self renderStepAtIndex:index];
  [self _restartAutoplayTimerIfNecessary];
}

#pragma mark - Download panel helpers
- (void)presentDownloadPanel {
  [statusLabel setStringValue:NSLocalizedString(@"Idle", @"Idle")];
  [manufacturerLabel setStringValue:NSLocalizedString(@"Unknown", @"Unknown")];
  [hardwareTypeLabel setStringValue:NSLocalizedString(@"Unknown", @"Unknown")];
  [romVersionLabel setStringValue:NSLocalizedString(@"Unknown", @"Unknown")];
  [romSizeLabel setStringValue:NSLocalizedString(@"Unknown", @"Unknown")];
  [NSApp runModalForWindow:downloadPanel];
  [downloadPanel orderOut:self];
}

- (void)dismissDownloadPanel {
  [NSApp stopModal];
}

- (NSString *) humanStringForBytes:(double)bytes {
  if (bytes < 1024) {
    return [NSString stringWithFormat:@"%i bytes", (int)bytes];
  }
  else if (bytes < 1024 * 1024) {
    return [NSString stringWithFormat:@"%iKB", (int)bytes / 1024];
  }
  else {
    double mb = (bytes / 1024.0 / 1024.0);
    if ((int)mb == mb) {
      return [NSString stringWithFormat:@"%iMB", (int)mb];
    }
    else {
      return [NSString stringWithFormat:@"%.2fMB", mb];
    }
  }
}

- (void)updateProgress:(NSNumber*)current {
  double currentVal = [current doubleValue];
  double maxVal = [progressIndicator maxValue];

  [progressIndicator setDoubleValue:currentVal];

  NSString *ofStr = [self humanStringForBytes:currentVal];
  NSString *toStr = [self humanStringForBytes:maxVal];
  
  NSString *formatString = NSLocalizedString(@"Downloaded %1$@ of %2$@", @"Downloaded %1$@ of %2$@");
  NSString *progressDesc = [NSString stringWithFormat:formatString, ofStr, toStr];

  [statusLabel setStringValue:progressDesc];
}

- (void)updateProgressMax:(NSNumber*)maximum {
  [progressIndicator setMaxValue:[maximum doubleValue]];
}

#pragma mark - File Saving
- (void)savePanelDidEnd:(NSSavePanel*)inSheet
             returnCode:(int)returnCode
            contextInfo:(void*)contextInfo
{
  NSDictionary *args = (NSDictionary *)contextInfo;
  if (returnCode == NSFileHandlingPanelOKButton) {
    NSURL *selectedURL = [inSheet URL];
    if (selectedURL != nil) {
      NSData *data = [args objectForKey:@"data"];
      [data writeToURL:selectedURL atomically:YES];
    }
  }
  [args release];
  [self dismiss:self];
}

- (void) runSavePanelWithArgs:(NSDictionary *)args {
  [self dismissDownloadPanel];
  
  NSSavePanel *savePanel = [NSSavePanel savePanel];
  [savePanel setCanCreateDirectories:YES];
  [savePanel setTitle:NSLocalizedString(@"Save ROM As...", @"Save ROM As...")];
  [savePanel setNameFieldStringValue:[args objectForKey:@"filename"]];
  
  [savePanel beginSheetForDirectory:NSHomeDirectory()
                               file:nil
                     modalForWindow:self.window
                      modalDelegate:self
                     didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
                        contextInfo:args];
}

#pragma mark - DebuggerController delegates
- (void) debuggerController:(DebuggerController *)controller updatedStatusMessage:(NSString *)statusMessage {
  [statusLabel performSelectorOnMainThread:@selector(setStringValue:)
                                     withObject:statusMessage
                                  waitUntilDone:NO];
}

- (void) debuggerController:(DebuggerController *)controller retrievedManufacturer:(NSString *)manufacturer{
  [manufacturerLabel performSelectorOnMainThread:@selector(setStringValue:)
                                           withObject:manufacturer
                                        waitUntilDone:NO];
}

- (void) debuggerController:(DebuggerController *)controller retrievedHardwareType:(NSString *)hardwareType{
  [hardwareTypeLabel performSelectorOnMainThread:@selector(setStringValue:)
                                           withObject:hardwareType
                                        waitUntilDone:NO];
}

- (void) debuggerController:(DebuggerController *)controller retrievedROMVersion:(NSString *)romVersion{
  [romVersionLabel performSelectorOnMainThread:@selector(setStringValue:)
                                         withObject:romVersion
                                      waitUntilDone:NO];
}

- (void) debuggerController:(DebuggerController *)controller retrievedROMSize:(uint32_t)romSize{
  NSString *statusMessage = [self humanStringForBytes:romSize];
  [romSizeLabel performSelectorOnMainThread:@selector(setStringValue:)
                                      withObject:statusMessage
                                   waitUntilDone:NO];
  
  [self performSelectorOnMainThread:@selector(updateProgressMax:)
                         withObject:[NSNumber numberWithInt:romSize]
                      waitUntilDone:NO];
}

- (void) debuggerController:(DebuggerController *)controller downloadedROMData:(NSData *)romData proposedFileName:(NSString *)filename {
  NSDictionary *args = [[NSDictionary alloc] initWithObjectsAndKeys:romData, @"data", filename, @"filename", nil];
  [self performSelectorOnMainThread:@selector(runSavePanelWithArgs:)
                         withObject:args
                      waitUntilDone:NO];
}

- (void) debuggerController:(DebuggerController *)controller updatedProgressValue:(uint32_t)progressValue {
  [self performSelectorOnMainThread:@selector(updateProgress:)
                         withObject:[NSNumber numberWithInt:progressValue]
                      waitUntilDone:NO];

}

- (void) debuggerControllerDidStart:(DebuggerController *)controller {
  [self performSelectorOnMainThread:@selector(presentDownloadPanel)
                         withObject:nil
                      waitUntilDone:NO];
}

- (void) debuggerControllerDidFinish:(DebuggerController *)controller {
  [self performSelectorOnMainThread:@selector(dismissDownloadPanel)
                         withObject:nil
                      waitUntilDone:NO];
}

#pragma mark - Notifications
- (void) urlClickedNotification:(NSNotification *)aNotification {
  NSURL *url = [[aNotification userInfo] objectForKey:@"url"];
  if ([[url scheme] isEqualToString:@"newten"] == NO) {
    return;
  }
  if ([[url host] isEqualToString:@"installpackage"] == NO) {
    return;
  }
  
  NSString *packageName = [[url path] substringFromIndex:1];
  NSString *path = [[NSBundle mainBundle] pathForResource:packageName ofType:nil];
  if (path == nil) {
    return;
  }

  [self _stopAutoplayTimer];

  AppDelegate *appDelgate = (id)[NSApp delegate];
  [appDelgate installPackages:[NSArray arrayWithObject:path] runAsModal:YES];
}

@end
