//
//  BTCache.h
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

@interface BTCache : NSObject
- (id)initWithDirectory:(NSSearchPathDirectory)directory;
- (void)store:(NSString*)bucket key:(NSString*)key data:(NSData*)data;
- (NSData*)get:(NSString*)bucket key:(NSString*)key;
- (bool)has:(NSString*)bucket key:(NSString*)key;
@end
