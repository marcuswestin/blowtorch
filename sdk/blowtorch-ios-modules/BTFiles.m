//
//  BTFiles.m
//  dogo
//
//  Created by Marcus Westin on 2/19/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTFiles.h"

@implementation BTFiles {
    NSString* _documentsDirectory;
    NSString* _cachesDirectory;
}

+ (BTFiles*) instance { return (BTFiles*) [super instance]; }

+ (NSData*)readDocument:(NSString*)filename {
    return [[self instance] readDocument:filename];
}
+ (NSData*)readCache:(NSString*)filename {
    return [[self instance] readCache:filename];
}
+ (BOOL)writeDocument:(NSString*)filename data:(NSData*)data {
    return [[self instance] writeDocument:filename data:data];
}
+ (BOOL)writeCache:(NSString*)filename data:(NSData*)data {
    return [[self instance] writeCache:filename data:data];
}
+ (NSString*)cachePath:(NSString*)filename {
    return [[self instance] _cachePath:filename];
}

- (void) setup:(BTAppDelegate*)app {
    
    _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    _cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    [app registerHandler:@"BTFiles.writeJsonDocument" handler:^(id data, BTResponseCallback responseCallback) {
        [self _writeJson:[self _documentPath:[data objectForKey:@"filename"]] jsonValue:[data objectForKey:@"jsonValue"] andRespond:responseCallback];
    }];
    [app registerHandler:@"BTFiles.writeJsonCache" handler:^(id data, BTResponseCallback responseCallback) {
        [self _writeJson:[self _cachePath:[data objectForKey:@"filename"]] jsonValue:[data objectForKey:@"jsonValue"] andRespond:responseCallback];
    }];
    [app registerHandler:@"BTFiles.readJsonDocument" handler:^(id data, BTResponseCallback responseCallback) {
        [self _readJson:[self _documentPath:[data objectForKey:@"filename"]] andRespond:responseCallback];
    }];
    [app registerHandler:@"BTFiles.readJsonCache" handler:^(id data, BTResponseCallback responseCallback) {
        [self _readJson:[self _cachePath:[data objectForKey:@"filename"]] andRespond:responseCallback];
    }];
}

- (NSData*)readDocument:(NSString*)filename {
    return [NSData dataWithContentsOfFile:[self _documentPath:filename]];
}
- (NSData*)readCache:(NSString*)filename {
    return [NSData dataWithContentsOfFile:[self _cachePath:filename]];
}
- (BOOL)writeDocument:(NSString*)filename data:(NSData*)data {
    return [data writeToFile:[self _documentPath:filename] atomically:YES];
}
- (BOOL)writeCache:(NSString*)filename data:(NSData*)data {
    return [data writeToFile:[self _cachePath:filename] atomically:YES];
}

- (void)_writeJson:(NSString*)path jsonValue:(id)jsonValue andRespond:(BTResponseCallback)responseCallback {
    NSError* jsonErr;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:jsonValue options:nil error:&jsonErr];
    if (jsonErr) { return responseCallback(jsonErr, nil); }
    BOOL writeErr = [jsonData writeToFile:path atomically:YES];
    responseCallback(writeErr ? @"Error writing json document" : nil, nil);
}
- (void)_readJson:(NSString*)path andRespond:(BTResponseCallback)responseCallback {
    NSData* documentData = [NSData dataWithContentsOfFile:path];
    if (!documentData) { return responseCallback(nil, nil); }
    NSError* err;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:documentData options:NSJSONReadingAllowFragments error:&err];
    responseCallback(err, jsonObject);
}

- (NSString*)_documentPath:(NSString*)filename {
    return [_documentsDirectory stringByAppendingPathComponent:filename];
}

- (NSString*)_cachePath:(NSString*)filename {
    return [_cachesDirectory stringByAppendingPathComponent:filename];
}

@end
