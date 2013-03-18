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

static BTFiles* instance;

+ (NSData*)readDocument:(NSString*)filename {
    return [instance readDocument:filename];
}
+ (NSData*)readCache:(NSString*)filename {
    return [instance readCache:filename];
}
+ (BOOL)writeDocument:(NSString*)filename data:(NSData*)data {
    return [instance writeDocument:filename data:data];
}
+ (BOOL)writeCache:(NSString*)filename data:(NSData*)data {
    return [instance writeCache:filename data:data];
}
+ (NSString*)cachePath:(NSString*)filename {
    return [instance _cachePath:filename];
}
+ (NSString*)documentPath:(NSString*)filename {
    return [instance _documentPath:filename];
}

- (void) setup:(BTAppDelegate*)app {
    if (instance) { return; }
    instance = self;
    _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    _cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    [app handleCommand:@"BTFiles.writeJsonDocument" handler:^(id data, BTCallback responseCallback) {
        [self _writeJson:[self _documentPath:[data objectForKey:@"filename"]] jsonValue:[data objectForKey:@"jsonValue"] andRespond:responseCallback];
    }];
    [app handleCommand:@"BTFiles.writeJsonCache" handler:^(id data, BTCallback responseCallback) {
        [self _writeJson:[self _cachePath:[data objectForKey:@"filename"]] jsonValue:[data objectForKey:@"jsonValue"] andRespond:responseCallback];
    }];
    [app handleCommand:@"BTFiles.readJsonDocument" handler:^(id data, BTCallback responseCallback) {
        [self _readJson:[self _documentPath:[data objectForKey:@"filename"]] andRespond:responseCallback];
    }];
    [app handleCommand:@"BTFiles.readJsonCache" handler:^(id data, BTCallback responseCallback) {
        [self _readJson:[self _cachePath:[data objectForKey:@"filename"]] andRespond:responseCallback];
    }];
    [app handleCommand:@"BTFiles.clearAll" handler:^(id data, BTCallback responseCallback) {
        [self _clearAll:data responseCallback:responseCallback];
    }];
    
    [app handleRequests:@"BTFiles.getDocument" handler:^(NSDictionary *params, WVPResponse *response) {
        [response respondWithData:[self readDocument:params[@"document"]] mimeType:params[@"mimeType"]];
    }];
}

- (void)_clearAll:(NSDictionary*)data responseCallback:(BTCallback)responseCallback {
    NSError *docsErr = [self _clearDirectory:_documentsDirectory];
    if (docsErr) { return responseCallback(docsErr, nil); }
    NSError* cacheErr = [self _clearDirectory:_cachesDirectory];
    if (cacheErr) { return responseCallback(cacheErr, nil); }
    responseCallback(nil, nil);
}

- (NSError*) _clearDirectory:(NSString*)directory {
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSError* err;
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:directory error:&err];
    if (err) { return err; }
    for (NSString *path in directoryContents) {
        NSString *fullPath = [directory stringByAppendingPathComponent:path];
        [fileMgr removeItemAtPath:fullPath error:&err];
        if (err) { return err; }
    }
    return nil;
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

- (void)_writeJson:(NSString*)path jsonValue:(id)jsonValue andRespond:(BTCallback)responseCallback {
    NSError* jsonErr;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:jsonValue options:0 error:&jsonErr];
    if (jsonErr) { return responseCallback(jsonErr, nil); }
    BOOL success = [jsonData writeToFile:path atomically:YES];
    responseCallback(success ? nil : @"Error writing json document", nil);
}
- (void)_readJson:(NSString*)path andRespond:(BTCallback)responseCallback {
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
