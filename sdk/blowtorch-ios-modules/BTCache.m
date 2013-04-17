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
    BOOL storeScheduled;
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

static NSString* filename = @"BTCacheInfo";

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    storeScheduled = NO;
    NSDictionary* cacheInfo = [NSDictionary dictionaryWithContentsOfFile:[BTFiles cachePath:filename]];
    _cacheInfo = [NSMutableDictionary dictionaryWithDictionary:cacheInfo];
}

- (void)store:(NSString *)key data:(NSData *)data {
    if (!data || !data.length) {
        NSLog(@"Refusing to cache 0-length data %@", key);
        return;
    }
    [BTFiles writeCache:[self _filenameFor:key] data:data];
    _cacheInfo[key] = [NSNumber numberWithInt:1];
    @synchronized(self) {
        if (storeScheduled) { return; }
        storeScheduled = YES;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        @synchronized(self) {
            [_cacheInfo writeToFile:[BTFiles cachePath:filename] atomically:YES];
            [BTFiles writeCache:[self _filenameFor:key] data:data];
            storeScheduled = NO;
        }
    });
}

- (NSData *)get:(NSString *)key {
    if (_cacheInfo[key]) {
        return [BTFiles readCache:[self _filenameFor:key]];
    } else {
        return nil;
    }
}

- (bool)has:(NSString *)key {
    id obj = _cacheInfo[key];
    return !!obj;
}

- (NSString *)_filenameFor:(NSString *)key {
    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    NSString* filename = [[key componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@""];
    return filename;
}
@end
