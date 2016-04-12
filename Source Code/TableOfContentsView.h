//
//  TableOfContentsView.h
//  Newt Dumper
//
//  Created by Steve White on 4/10/16.
//  Copyright © 2016 Steve White. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TableOfContentsView : NSView {
  NSArray *_pageViews;
  NSArray *_titles;
  NSInteger _selectedTitleIndex;
}

@property (retain, nonatomic) NSArray *titles;
@property (assign, nonatomic) NSInteger selectedTitleIndex;
@end

@interface DotView : NSView {
  BOOL _selected;
}
@property (assign, nonatomic) BOOL selected;
@end

@interface PageView : NSView {
  NSTextField *_textLabel;
  DotView *_dotView;
  BOOL _selected;
  NSColor *_color;
}
@property (retain, nonatomic, readonly) NSTextField *textLabel;
@property (retain, nonatomic, readonly) DotView *dotView;
@property (assign, nonatomic) BOOL selected;

- (void) sizeToFit;
@end