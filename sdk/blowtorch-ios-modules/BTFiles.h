//
//  BTFiles.h
//  dogo
//
//  Created by Marcus Westin on 2/19/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTModule.h"

@interface BTFiles : BTModule

+ (BTFiles*) instance;
+ (NSData*)readDocument:(NSString*)filename;
+ (NSData*)readCache:(NSString*)filename;
+ (BOOL)writeDocument:(NSString*)filename data:(NSData*)data;
+ (BOOL)writeCache:(NSString*)filename data:(NSData*)data;
+ (NSString*)cachePath:(NSString*)filename;

@end
