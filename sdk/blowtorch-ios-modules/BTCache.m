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
    NSMutableDictionary* _memory;
}

static BTCache* instance;

+ (void)store:(NSString*)key data:(NSData*)data { [self store:key data:data cacheInMemory:NO]; }
+ (void)store:(NSString *)key data:(NSData *)data cacheInMemory:(BOOL)cacheInMemory {
    return [instance store:key data:data cacheInMemory:cacheInMemory];
}
+ (NSData*)get:(NSString*)key { return [self get:key cacheInMemory:NO]; }
+ (NSData *)get:(NSString *)key cacheInMemory:(BOOL)cacheInMemory {
    return [instance get:key cacheInMemory:cacheInMemory];
}

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    _memory = [NSMutableDictionary dictionary];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:[self _path:@"BTCache"] withIntermediateDirectories:YES attributes:NULL error:NULL];

    [app handleCommand:@"BTCache.clear" handler:^(id params, BTCallback callback) {
        NSError* err;
        [[NSFileManager defaultManager] removeItemAtPath:[self _path:params[@"key"]] error:&err];
        callback(err,nil);
    }];
    [app handleCommand:@"BTCache.clearAll" handler:^(id params, BTCallback callback) {
        NSError* err;
        [[NSFileManager defaultManager] removeItemAtPath:[self _path:@"BTCache/"] error:&err];
        if (err && err.code != NSFileNoSuchFileError) {
            return callback(err,nil);
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:[self _path:@"BTCache"] withIntermediateDirectories:YES attributes:NULL error:NULL];
        callback(nil,nil);
    }];
}

- (NSString*) _path:(NSString*)filename {
    return [BTFiles cachePath:filename];
}

- (void)store:(NSString *)key data:(NSData *)data cacheInMemory:(BOOL)cacheInMemory {
    if (!key || !key.length) {
        NSLog(@"Refusing to cache 0-length key");
        return;
    }
    if (!data || !data.length) {
        NSLog(@"Refusing to cache 0-length data %@", key);
        return;
    }
    [data writeToFile:[self _path:[self _filenameFor:key]] atomically:YES];
    if (cacheInMemory) {
        _memory[key] = data;
    }
}

- (NSData *)get:(NSString *)key cacheInMemory:(BOOL)cacheInMemory {
    if (_memory[key]) { return _memory[key]; }
    NSData* data = [NSData dataWithContentsOfFile:[self _path:[self _filenameFor:key]]];
    if (cacheInMemory && data.length) {
        _memory[key] = data;
    }
    return data;
}

- (NSString *)_filenameFor:(NSString *)key {
    static NSCharacterSet* illegalFileNameCharacters = nil;
    if (!illegalFileNameCharacters) {
        illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    }
    
    NSString* filename = [[key componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@""];
    return [@"BTCache/" stringByAppendingString:filename];
}
@end
