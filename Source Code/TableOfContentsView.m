//
//  TableOfContentsView.m
//  Newt Dumper
//
//  Created by Steve White on 4/10/16.
//  Copyright © 2016 Steve White. All rights reserved.
//

#import "TableOfContentsView.h"

#define ItemPadding 4

@implementation TableOfContentsView {
  NSArray *_pageViews;
}

- (void) dealloc {
  [_pageViews release], _pageViews = nil;
  [super dealloc];
}

- (BOOL) isFlipped {
  return YES;
}

- (void) _reflowPageViews {
  NSRect pageFrame = NSZeroRect;
  pageFrame.size.width = self.bounds.size.width;
  pageFrame.size.height = 17;
  pageFrame.origin.y = ItemPadding;
  
  for (PageView *aPageView in _pageViews) {
    aPageView.frame = pageFrame;
    [aPageView sizeToFit];
    pageFrame.origin.y = NSMaxY(aPageView.frame) + (ItemPadding * 2);
  }
}

- (void) _updateSelectedPage {
  NSInteger numOfTitles = [self.titles count];
  
  for (NSInteger titleIndex=0; titleIndex<numOfTitles; titleIndex++) {
    PageView *pageView = [_pageViews objectAtIndex:titleIndex];
    pageView.selected = (titleIndex == _selectedTitleIndex);
  }

  // Chaning the bold trait may cause the item to need more/less
  // height.  So we reflow them after changing this..
  [self _reflowPageViews];
}

- (void) _rebuildPageViews {
  if (_pageViews != nil) {
    for (NSView *aPageView in _pageViews) {
      [aPageView removeFromSuperview];
    }
    [_pageViews release], _pageViews = nil;
  }
  
  
  NSMutableArray *pageViews = [[NSMutableArray alloc] init];
  
  for (NSString *aTitle in self.titles) {
    PageView *pageView = [[[PageView alloc] init] autorelease];
    pageView.autoresizingMask = NSViewWidthSizable;
    pageView.textLabel.stringValue = aTitle;
    [self addSubview:pageView];
    [pageViews addObject:pageView];
  }
  _pageViews = pageViews;
  
  [self _reflowPageViews];
  [self _updateSelectedPage];
}

- (void) setTitles:(NSArray *)titles {
  if (_titles != nil) {
    [_titles release], _titles = nil;
  }
  
  _titles = [titles retain];
  [self _rebuildPageViews];
}

- (void) setSelectedTitleIndex:(NSInteger)selectedTitleIndex {
  _selectedTitleIndex = selectedTitleIndex;
  [self _updateSelectedPage];
}

@end

@implementation DotView

- (void) setSelected:(BOOL)selected {
  if (selected == _selected) {
    return;
  }
  
  _selected = selected;
  [self setNeedsDisplay:YES];
}

- (void) drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  NSColor *color = nil;
  if (self.selected == YES) {
    color = [NSColor colorWithDeviceRed:0.399 green:0.690 blue:0.939 alpha:1.000];
  }
  else {
    color = [NSColor colorWithDeviceWhite:0.584 alpha:1.000];
  }
  
  [color setFill];
  
  NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:dirtyRect];
  [path fill];
}

@end

@implementation PageView

- (instancetype) initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self != nil) {
    _dotView = [[[DotView alloc] initWithFrame:NSMakeRect(0, 5, 8, 8)] autorelease];
    [self addSubview:_dotView];

    CGFloat maxLabelWidth = frameRect.size.width - 20;
    _textLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(10, 0, maxLabelWidth, frameRect.size.height)] autorelease];
    _textLabel.preferredMaxLayoutWidth = maxLabelWidth;
    _textLabel.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _textLabel.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
    _textLabel.drawsBackground = NO;
    _textLabel.backgroundColor = nil;
    _textLabel.bordered = NO;
    _textLabel.focusRingType = NSFocusRingTypeNone;
    _textLabel.textColor = [NSColor labelColor];
    _textLabel.editable = NO;
    _textLabel.maximumNumberOfLines = 0;
    _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _textLabel.cell.wraps = YES;
    _textLabel.cell.scrollable = NO;
    _textLabel.cell.usesSingleLineMode = NO;
    [self addSubview:_textLabel];
  }
  return self;
}

- (BOOL) isFlipped {
  return YES;
}

- (void) sizeToFit {
  NSRect frame = self.frame;
  
  NSRect textRect = [_textLabel.stringValue boundingRectWithSize:NSMakeSize(frame.size.width - 20, CGFLOAT_MAX)
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:[NSDictionary dictionaryWithObject:_textLabel.font forKey:NSFontAttributeName]];
  
  frame.size.height = ceilf(textRect.size.height);
  self.frame = frame;
}

- (void) setSelected:(BOOL)selected {
  if (selected == _selected) {
    return;
  }
  
  _selected = selected;
  
  NSFont *font = nil;
  if (_selected == YES) {
    font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
  }
  else {
    font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
  }
  _textLabel.font = font;
  
  _dotView.selected = selected;
}

@end