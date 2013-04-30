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
+ (NSData*)read:(NSDictionary*)params {
    return [instance read:params];
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
+ (NSString*)path:(NSDictionary*)params {
    if (params[@"file"]) { return params[@"file"]; }
    if (params[@"filename"]) { return params[@"filename"]; }
    if (params[@"document"]) { return [BTFiles documentPath:params[@"document"]]; }
    if (params[@"cache"]) { return [BTFiles cachePath:params[@"cache"]]; }
    return nil;
}

- (void) setup:(BTAppDelegate*)app {
    if (instance) { return; }
    instance = self;
    _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    _cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    
    [app handleCommand:@"BTFiles.writeJson" handler:^(id data, BTCallback responseCallback) {
        [self _writeJson:[BTFiles path:data] jsonValue:[data objectForKey:@"jsonValue"] andRespond:responseCallback];
    }];
    [app handleCommand:@"BTFiles.readJson" handler:^(id data, BTCallback responseCallback) {
        [self _readJson:[BTFiles path:data] andRespond:responseCallback];
    }];
    [app handleCommand:@"BTFiles.clearAll" handler:^(id data, BTCallback responseCallback) {
        [self _clearAll:data responseCallback:responseCallback];
    }];
    [app handleRequests:@"BTFiles.read" handler:^(NSDictionary *params, WVPResponse *response) {
        [response respondWithData:[self read:params] mimeType:params[@"mimeType"]];
    }];
    [app handleCommand:@"BTFiles.fetch" handler:^(id params, BTCallback callback) {
        [self async:^{
            NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:params[@"url"]]];
            if (!data) { return callback(@"Could not fetch data", nil); }
            BOOL success = [data writeToFile:[BTFiles path:params] atomically:YES];
            callback(success ? nil : @"Coult not write fetched data", nil);
        }];
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

- (NSData*)read:(NSDictionary*)params {
    return [NSData dataWithContentsOfFile:[BTFiles path:params]];
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
