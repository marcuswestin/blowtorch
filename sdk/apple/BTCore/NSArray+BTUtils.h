//
//  NSArray+BTUtils.h
//  Dogo
//
//  Created by Marcus Westin on 6/13/13.
//  Copyright (c) 2013 Flutterby Labs Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef id (^HHSyncIterate)(id object, NSUInteger index);

@interface NSArray (BTUtils)

- (CGSize)makeSize;
- (CGRect)makeRect;
- (CGPoint)makePoint;

- (NSMutableArray*) map:(HHSyncIterate)iterate;

@end
