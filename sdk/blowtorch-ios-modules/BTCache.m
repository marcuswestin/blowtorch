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
    NSDictionary* cacheInfo = [NSDictionary dictionaryWithContentsOfFile:[BTFiles cachePath:@"BTCache._cacheInfo"]];
    _cacheInfo = [NSMutableDictionary dictionaryWithDictionary:cacheInfo];
}

- (void)store:(NSString *)key data:(NSData *)data {
    _cacheInfo[key] = [NSNumber numberWithInt:1];
    [_cacheInfo writeToFile:[BTFiles cachePath:@"BTCache._cacheInfo"] atomically:YES];
    [BTFiles writeCache:[self _filenameFor:key] data:data];
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
