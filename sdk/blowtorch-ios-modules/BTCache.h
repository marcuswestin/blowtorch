//
//  BTCache.h
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTModule.h"

@interface BTCache : BTModule

+ (BTCache*)instance;

+ (void)store:(NSString*)key data:(NSData*)data;
+ (NSData*)get:(NSString*)key;
+ (bool)has:(NSString*)key;

@end
