//
//  BTCache.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import "BTCache.h"

@interface BTCache (hidden)
- (NSString*)_nameFor:(NSString*)bucket key:(NSString*)key;
- (NSString*)_pathFor:(NSString*)name;
- (NSString *)_sanitizeFileNameString:(NSString *)fileName;
@end

@implementation BTCache {
    NSSearchPathDirectory _searchPathDirectory;
    NSMutableDictionary* _cacheInfo;
    NSString* _cacheInfoPath;
}

- (id)initWithDirectory:(NSSearchPathDirectory)searchPathDirectory {
    if (self = [super init]) {
        _searchPathDirectory = searchPathDirectory;
        _cacheInfoPath = [self _pathFor:[self _nameFor:@"BTCache" key:@"cacheInfo"]];
        _cacheInfo = [NSMutableDictionary dictionaryWithContentsOfFile:_cacheInfoPath];
        if (!_cacheInfo) { _cacheInfo = [NSMutableDictionary dictionary]; }
    }
    return self;
}

- (void)store:(NSString *)bucket key:(NSString *)key data:(NSData *)data {
    @synchronized(self) {
        NSString* name = [self _nameFor:bucket key:key];
        [_cacheInfo setObject:[NSNumber numberWithInt:1] forKey:name];
        [_cacheInfo writeToFile:_cacheInfoPath atomically:YES];
        [data writeToFile:[self _pathFor:name] atomically:YES];
    }
}

- (NSData *)get:(NSString *)bucket key:(NSString *)key {
    NSString* name = [self _nameFor:bucket key:key];
    if ([_cacheInfo objectForKey:name]) {
        return [NSData dataWithContentsOfFile:[self _pathFor:name]];
    } else {
        return nil;
    }
}

- (bool)has:(NSString *)bucket key:(NSString *)key {
    return !![_cacheInfo objectForKey:[self _nameFor:bucket key:key]];
}
@end

@implementation BTCache (hidden)
- (NSString *)_nameFor:(NSString *)bucket key:(NSString *)key {
    return [bucket stringByAppendingString:[self _sanitizeFileNameString:key]];
}
- (NSString *)_pathFor:(NSString *)name {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(_searchPathDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:name];
}
- (NSString *)_sanitizeFileNameString:(NSString *)fileName {
    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    return [[fileName componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@""];
}
@end
