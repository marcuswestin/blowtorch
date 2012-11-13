//
//  NSString+Util.m
//  dogo
//
//  Created by Marcus Westin on 11/13/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import "NSString+Util.h"

@implementation NSString (Util)

- (NSString *)urlEncodedString {
    return (__bridge NSString*) CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)self, NULL,
                                                                        (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
}

@end
