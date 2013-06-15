//
//  NSString+Util.h
//  dogo
//
//  Created by Marcus Westin on 11/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Util)

- (NSString*)urlEncodedString;

@end

@interface NSObject (Util)

- (NSString*)toJson;

@end