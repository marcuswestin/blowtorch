//
//  NSString+BTUtils.m
//  Dogo
//
//  Created by Marcus Westin on 6/13/13.
//  Copyright (c) 2013 Flutterby Labs Inc. All rights reserved.
//

#import "NSString+BTUtils.h"
#import "NSArray+BTUtils.h"

@implementation NSString (BTUtils)

// x.y.w.h -> CGRect
- (CGRect)makeRect {
    return [[self _dotSeperated] makeRect];
}
// w.h -> CGSize
- (CGSize)makeSize {
    return [[self _dotSeperated] makeSize];
}
// x.y -> CGPoint
- (CGPoint)makePoint {
    return [[self _dotSeperated] makePoint];
}

- (NSArray*) _dotSeperated {
    return [self componentsSeparatedByString:@","];
}

- (NSMutableDictionary *)parseQueryParams {
    NSMutableDictionary *queryComponents = [NSMutableDictionary dictionary];
    for(NSString *keyValuePairString in [self componentsSeparatedByString:@"&"]) {
        NSArray *keyValuePairArray = [keyValuePairString componentsSeparatedByString:@"="];
        if ([keyValuePairArray count] < 2) continue; // Verify that there is at least one key, and at least one value.  Ignore extra = signs
        NSString *key = [[keyValuePairArray objectAtIndex:0] decodeURIComponent];
        NSString* rawValue = [keyValuePairArray objectAtIndex:1];
        id value;
        if ([rawValue rangeOfString:@","].location == NSNotFound) {
            value = [rawValue decodeURIComponent];
        } else {
            value = [[rawValue componentsSeparatedByString:@","] map:^id(NSString* part, NSUInteger index) {
                return [part decodeURIComponent];
            }];
        }
        [queryComponents setObject:value forKey:key];
    }
    return queryComponents;
}

- (NSString *)decodeURIComponent {
    NSString *result = [self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    return [result stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)encodeURIComponent {
    NSString *result = [self stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    return [result stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}
@end
