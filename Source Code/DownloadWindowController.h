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

@interface DownloadWindowController : NSWindowController<DebuggerControllerDelegate, NSTabViewDelegate> {
  DebuggerController *_debugController;
}

@property (assign, nonatomic) IBOutlet NSView *contentView;
@property (assign, nonatomic) IBOutlet NSTabView *tabView;
@property (assign, nonatomic) IBOutlet ScreencastView *screencast;
@property (assign, nonatomic) IBOutlet NSView *screencastButtons;
@property (assign, nonatomic) IBOutlet NSButton *downloadButton;
@property (assign, nonatomic) IBOutlet NSButton *closeButton;
@property (assign, nonatomic) IBOutlet TableOfContentsView *toc;

// For the download panel/sheet.
@property (assign, nonatomic) IBOutlet NSPanel *downloadPanel;
@property (assign, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign, nonatomic) IBOutlet NSTextFieldCell *statusLabel;
@property (assign, nonatomic) IBOutlet NSTextFieldCell *manufacturerLabel;
@property (assign, nonatomic) IBOutlet NSTextFieldCell *hardwareTypeLabel;
@property (assign, nonatomic) IBOutlet NSTextFieldCell *romVersionLabel;
@property (assign, nonatomic) IBOutlet NSTextFieldCell *romSizeLabel;

//
@property (strong, nonatomic) NSArray *steps;
@property (assign, nonatomic) NSInteger stepIndex;

@property (strong, nonatomic) NSTimer *autoplayTimer;
@property (assign, nonatomic, readonly, getter=isAutoplaying) BOOL autoplaying;

// Actions
- (IBAction)download:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)toggleAutoplayTimer:(id)sender;

@end
