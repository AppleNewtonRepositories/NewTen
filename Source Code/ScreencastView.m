//
//  ScreencastView.m
//  Newt Dumper
//
//  Created by Steve White on 4/10/16.
//  Copyright © 2016 Steve White. All rights reserved.
//

#import "ScreencastView.h"


@implementation ScreencastView 

- (void) awakeFromNib {
  [super awakeFromNib];

  _highlightView = [[HighlightView alloc] initWithFrame:self.bounds];
  _highlightView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [self addSubview:_highlightView];
}

- (void) dealloc {
  [_highlightView removeFromSuperview];
  [_highlightView release], _highlightView = nil;
  [_imageViewsByIdentifier release], _imageViewsByIdentifier = nil;
  
  [super dealloc];
}

- (void) removeAllImages {
  for (NSString *anIdentifier in _imageViewsByIdentifier) {
    NSView *view = [_imageViewsByIdentifier objectForKey:anIdentifier];
    [view removeFromSuperview];
  }
  [_imageViewsByIdentifier removeAllObjects];
  [_highlightView setHighlightRect:NSZeroRect];
}

- (NSSize) contentSize {
  CGFloat minX=CGFLOAT_MAX,minY=CGFLOAT_MAX,maxX=0,maxY=0;
  for (NSString *anImageIdentifier in _imageViewsByIdentifier) {
	  NSView *imageView = [_imageViewsByIdentifier objectForKey:anImageIdentifier];
    NSRect frame = imageView.frame;
    minX = MIN(minX, NSMinX(frame));
    minY = MIN(minY, NSMinY(frame));
    maxX = MAX(maxX, NSMaxX(frame));
    maxY = MAX(maxY, NSMaxY(frame));
  }
  return NSMakeSize(maxX, maxY);
}

- (BOOL) isFlipped {
  return YES;
}

- (NSArray *) allIdentifiers {
  return [_imageViewsByIdentifier allKeys];
}

- (void) setHidden:(BOOL)hidden forImageWithIdentifier:(NSString *)identifier {
  NSImageView *imageView = [_imageViewsByIdentifier objectForKey:identifier];
  if (imageView == nil) {
    NSLog(@"%s couldn't find image view for identifier:%@", __PRETTY_FUNCTION__, identifier);
  }
  else {
	  [imageView setHidden:hidden];
  }
}

- (void) addImageNamed:(NSString *)imageName atPoint:(NSPoint)point withIdentifier:(NSString *)identifier {
  NSImage *image = [NSImage imageNamed:imageName];
  if (image == nil) {
    NSLog(@"%s imageNamed:%@ returned nil!", __PRETTY_FUNCTION__, imageName);
    return;
  }
  
  NSRect viewFrame = NSZeroRect;
  viewFrame.origin = point;
  viewFrame.size = image.size;

  NSImageView *imageView = [[[NSImageView alloc] initWithFrame:viewFrame] autorelease];
  imageView.image = image;

  [self addSubview:imageView positioned:NSWindowBelow relativeTo:_highlightView];
  
  if (_imageViewsByIdentifier == nil) {
    _imageViewsByIdentifier = [[NSMutableDictionary alloc] init];
  }
  
  if (identifier != nil) {
    [_imageViewsByIdentifier setObject:imageView forKey:identifier];
  }
}

- (void) highlightRect:(NSRect)highlightRect {
  _highlightView.highlightRect = highlightRect;
}

@end


@implementation HighlightView

@synthesize highlightRect = _highlightRect;

- (BOOL) isFlipped {
  return YES;
}

- (void) setHighlightRect:(NSRect)highlightRect {
  _highlightRect = highlightRect;
  [self setNeedsDisplay:YES];
}

- (void) drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];
  
  if (NSEqualRects(NSZeroRect, _highlightRect) == YES) {
    return;
  }
  
  NSBezierPath *arrowPath = [NSBezierPath bezierPath];
  
  NSPoint topCenter = NSMakePoint(NSMidX(_highlightRect), NSMinY(_highlightRect) - 5);
  
  [arrowPath moveToPoint:topCenter];
  [arrowPath lineToPoint:NSMakePoint(topCenter.x - 5, topCenter.y - 5)];
  [arrowPath lineToPoint:topCenter];
  [arrowPath lineToPoint:NSMakePoint(topCenter.x + 5, topCenter.y - 5)];
  [arrowPath lineToPoint:topCenter];
  [arrowPath lineToPoint:NSMakePoint(topCenter.x, topCenter.y - 50)];
  [arrowPath setLineWidth:2];
  
  [[NSColor redColor] setStroke];
  [arrowPath stroke];
  
  NSRect outline = NSInsetRect(_highlightRect, -1, -1);
  NSBezierPath *outlinePath = [NSBezierPath bezierPathWithRect:outline];
  [outlinePath setLineWidth:2];
  [outlinePath stroke];
}

@end