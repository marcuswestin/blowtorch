//
//  BTModule.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import "BTModule.h"

@implementation BTModule

+ (void) setup:(BTAppDelegate*)app {
    BTModule* module = [[self alloc] init];
    [module setup:app];
}
// override this in module instances
- (void) setup:(BTAppDelegate*)app {}

// Utitlities
- (NSMutableDictionary *)parseQueryParams:(NSString *)queryString {
    NSMutableDictionary *queryComponents = [NSMutableDictionary dictionary];
    for(NSString *keyValuePairString in [queryString componentsSeparatedByString:@"&"]) {
        NSArray *keyValuePairArray = [keyValuePairString componentsSeparatedByString:@"="];
        if ([keyValuePairArray count] < 2) continue; // Verify that there is at least one key, and at least one value.  Ignore extra = signs
        NSString *key = [self decodeURIComponent:[keyValuePairArray objectAtIndex:0]];
        NSString *value = [self decodeURIComponent:[keyValuePairArray objectAtIndex:1]];
        [queryComponents setObject:value forKey:key];
    }
    return queryComponents;
}
- (NSString *)decodeURIComponent:(NSString *)string {
    NSString *result = [string stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    return [result stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}
- (NSString *)encodeURIComponent:(NSString *)string {
    NSString *result = [string stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    return [result stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}
@end
