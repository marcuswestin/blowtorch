//
//  NSArray+BTUtils.m
//  Dogo
//
//  Created by Marcus Westin on 6/13/13.
//  Copyright (c) 2013 Flutterby Labs Inc. All rights reserved.
//

#import "NSArray+BTUtils.h"

@implementation NSArray (BTUtils)

- (CGSize)makeSize {
    return CGSizeMake([self _floatAt:0], [self _floatAt:1]);
}

- (CGRect)makeRect {
    return CGRectMake([self _floatAt:0], [self _floatAt:1], [self _floatAt:2], [self _floatAt:3]);
}

- (CGPoint)makePoint {
    return CGPointMake([self _floatAt:0], [self _floatAt:1]);
}

- (float)_floatAt:(NSUInteger)index {
    return [[self objectAtIndex:index] floatValue];
}

- (NSMutableArray*) map:(HHSyncIterate)iterate {
    NSUInteger count = [self count];
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i=0; i<count; i++) {
        [results addObject:iterate([self objectAtIndex:i], i)];
    }
    return results;
}

@end
