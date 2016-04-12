//
//  DownloadWindowController.h
//  NewTen
//
//  Created by Steve White on 4/11/16.
//
//

#import <Cocoa/Cocoa.h>
#import "DebuggerController.h"

@class ScreencastView;
@class TableOfContentsView;

@interface DownloadWindowController : NSWindowController<DebuggerControllerDelegate> {
  DebuggerController *_debugController;

  IBOutlet NSView *contentView;
  IBOutlet NSTabView *tabView;
  IBOutlet ScreencastView *screencast;
  IBOutlet NSView *screencastButtons;
  IBOutlet NSButton *downloadButton;
  IBOutlet NSButton *closeButton;
  IBOutlet TableOfContentsView *toc;
  
  // For the download panel/sheet.
  IBOutlet NSPanel *downloadPanel;
  IBOutlet NSProgressIndicator *progressIndicator;
  IBOutlet NSTextFieldCell *statusLabel;
  IBOutlet NSTextFieldCell *manufacturerLabel;
  IBOutlet NSTextFieldCell *hardwareTypeLabel;
  IBOutlet NSTextFieldCell *romVersionLabel;
  IBOutlet NSTextFieldCell *romSizeLabel;
  
  //
  NSArray *_steps;
  NSInteger _stepIndex;
  NSTimer *_autoplayTimer;
}


//
@property (retain, nonatomic) NSArray *steps;
@property (assign, nonatomic) NSInteger stepIndex;

@property (retain, nonatomic) NSTimer *autoplayTimer;
@property (assign, nonatomic, readonly, getter=isAutoplaying) BOOL autoplaying;

// Actions
- (IBAction)download:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)toggleAutoplayTimer:(id)sender;

@end
