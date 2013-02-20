//
//  BTCache.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTCache.h"
#import "BTFiles.h"

@implementation BTCache {
    NSMutableDictionary* _cacheInfo;
}

static BTCache* instance;

+ (void)store:(NSString*)key data:(NSData*)data {
    return [instance store:key data:data];
}
+ (NSData*)get:(NSString*)key {
    return [instance get:key];
}
+ (bool)has:(NSString*)key {
    return [instance has:key];
}

- (void)setup:(BTAppDelegate *)app {
    instance = self;
    _cacheInfo = [NSMutableDictionary dictionaryWithContentsOfFile:[BTFiles cachePath:@"BTCache._cacheInfo"]];
}

- (void)store:(NSString *)key data:(NSData *)data {
    @synchronized(self) {
        NSString* name = [self _filenameFor:key];
        [_cacheInfo setObject:[NSNumber numberWithInt:1] forKey:name];
        [_cacheInfo writeToFile:[BTFiles cachePath:@"BTCache._cacheInfo"] atomically:YES];
        [BTFiles writeCache:name data:data];
    }
}

- (NSData *)get:(NSString *)key {
    NSString* name = [self _filenameFor:key];
    if ([_cacheInfo objectForKey:name]) {
        return [BTFiles readCache:name];
    } else {
        return nil;
    }
}

- (bool)has:(NSString *)key {
    return !![_cacheInfo objectForKey:[self _filenameFor:key]];
}

- (NSString *)_filenameFor:(NSString *)key {
    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    return [[key componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@""];
}
@end
