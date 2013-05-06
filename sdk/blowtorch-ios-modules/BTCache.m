//
//  BTCache.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTCache.h"
#import "BTFiles.h"

@implementation BTCache

static BTCache* instance;

+ (void)store:(NSString*)key data:(NSData*)data {
    return [instance store:key data:data];
}
+ (NSData*)get:(NSString*)key {
    return [instance get:key];
}

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
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

- (void)store:(NSString *)key data:(NSData *)data {
    if (!key || !key.length) {
        NSLog(@"Refusing to cache 0-length key");
        return;
    }
    if (!data || !data.length) {
        NSLog(@"Refusing to cache 0-length data %@", key);
        return;
    }
    [data writeToFile:[self _path:[self _filenameFor:key]] atomically:YES];
}

- (NSData *)get:(NSString *)key {
    return [NSData dataWithContentsOfFile:[self _path:[self _filenameFor:key]]];
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
