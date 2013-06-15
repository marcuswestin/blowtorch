//
//  BTEnumeration.h
//  dogo
//
//  Created by Marcus Westin on 5/7/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BTEnumeration : NSObject

+ (BTEnumeration*) enum:(NSString*)paramName default:(int)defaultEnumVal string:(NSString*)stringVal;
- (BTEnumeration*) add:(int)enumVal string:(NSString*)stringVal;
- (int)from:(NSDictionary*)params;
- (BOOL)from:(NSDictionary*)params is:(NSString*)stringVal;
- (BOOL)value:(int)enumValue is:(NSString*)stringVal;
@end
