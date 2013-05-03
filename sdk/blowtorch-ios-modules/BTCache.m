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

static NSString* infoFilename = @"BTCacheInfo";

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    storeScheduled = NO;
    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:[self _path:infoFilename]];
    _cacheInfo = [NSMutableDictionary dictionaryWithDictionary:dict];
    
    [app handleCommand:@"BTCache.clear" handler:^(id params, BTCallback callback) {
        [_cacheInfo removeObjectForKey:params[@"key"]];
        [self _scheduleWrite];
        callback(nil,nil);
    }];
    [app handleCommand:@"BTCache.clearAll" handler:^(id params, BTCallback callback) {
        _cacheInfo = [NSMutableDictionary dictionaryWithContentsOfFile:[self _path:infoFilename]];
        [self _writeNow];
        callback(nil,nil);
    }];
}

- (void)store:(NSString *)key data:(NSData *)data {
    if (!data || !data.length) {
        NSLog(@"Refusing to cache 0-length data %@", key);
        return;
    }
    [data writeToFile:[self _path:[self _filenameFor:key]] atomically:YES];
    _cacheInfo[key] = [NSNumber numberWithInt:1];
    [self _scheduleWrite];
}

- (void) _scheduleWrite {
    @synchronized(self) {
        if (storeScheduled) { return; }
        storeScheduled = YES;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self _writeNow];
    });
}

- (NSString*) _path:(NSString*)filename {
    return [BTFiles cachePath:filename];
}

- (void) _writeNow {
    @synchronized(self) {
        [_cacheInfo writeToFile:[self _path:infoFilename] atomically:YES];
        storeScheduled = NO;
    }
}

- (NSData *)get:(NSString *)key {
    if (_cacheInfo[key]) {
        return [NSData dataWithContentsOfFile:[self _path:[self _filenameFor:key]]];
    } else {
        return nil;
    }
}

- (BOOL)has:(NSString *)key {
    BOOL doesHave = !!_cacheInfo[key];
    return doesHave;
}

- (NSString *)_filenameFor:(NSString *)key {
    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    NSString* filename = [[key componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@""];
    return [@"BTCache-" stringByAppendingString:filename];
}
@end
