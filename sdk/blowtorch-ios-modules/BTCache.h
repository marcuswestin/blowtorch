//
//  BTCache.h
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTModule.h"

@interface BTCache : BTModule

+ (void)store:(NSString*)key data:(NSData*)data;
+ (void)store:(NSString*)key data:(NSData*)data cacheInMemory:(BOOL)cacheInMemory;
+ (NSData*)get:(NSString*)key;
+ (NSData*)get:(NSString*)key cacheInMemory:(BOOL)cacheInMemory;

@end
