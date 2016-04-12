//
//  ScreencastView.h
//  Newt Dumper
//
//  Created by Steve White on 4/10/16.
//  Copyright © 2016 Steve White. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HighlightView : NSView {
  NSRect _highlightRect;
}

@property (assign, nonatomic) NSRect highlightRect;

@end

@interface ScreencastView : NSView {
  NSMutableDictionary *_imageViewsByIdentifier;
  HighlightView *_highlightView;
}

- (NSSize) contentSize;
- (void) removeAllImages;

- (NSArray *) allIdentifiers;
- (void) addImageNamed:(NSString *)imageName atPoint:(NSPoint)point withIdentifier:(NSString *)identifier;
- (void) setHidden:(BOOL)hidden forImageWithIdentifier:(NSString *)identifier;
- (void) highlightRect:(NSRect)highlightRect;

@end
