//
//  NSString+Util.m
//  dogo
//
//  Created by Marcus Westin on 11/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "NSString+Util.h"

@implementation NSString (Util)

- (NSString *)urlEncodedString {
    return (__bridge NSString*) CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)self, NULL,
                                                                        (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
}

@end

@implementation NSObject (Util)

- (NSString *)toJson {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self options:0 error:nil] encoding:NSUTF8StringEncoding];
}

@end