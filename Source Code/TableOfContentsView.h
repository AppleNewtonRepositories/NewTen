//
//  TableOfContentsView.h
//  Newt Dumper
//
//  Created by Steve White on 4/10/16.
//  Copyright © 2016 Steve White. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TableOfContentsView : NSView
@property (strong, nonatomic) NSArray *titles;
@property (assign, nonatomic) NSInteger selectedTitleIndex;
@end

@interface DotView : NSView
@property (assign, nonatomic) BOOL selected;
@end

@interface PageView : NSView
@property (strong, nonatomic, readonly) NSTextField *textLabel;
@property (strong, nonatomic, readonly) DotView *dotView;
@property (assign, nonatomic) BOOL selected;
@property (strong, nonatomic) NSColor *color;

- (void) sizeToFit;
@end