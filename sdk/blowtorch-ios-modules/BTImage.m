//
//  BTImage.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTImage.h"
#import "UIImage+Resize.h"
#import "UIImage+HHImages.h"
#import "BTCache.h"
#import "BTFiles.h"

@implementation BTImage {
    NSOperationQueue* queue;
    NSMutableDictionary* loading;
    NSMutableDictionary* processing;
}

static BTImage* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    loading = [NSMutableDictionary dictionary];
    processing = [NSMutableDictionary dictionary];
    queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 10;
    [app handleRequests:@"BTImage.fetchImage" handler:^(NSDictionary *params, WVPResponse *response) {
        [self fetchImage:params response:response];
    }];
    [app handleRequests:@"BTImage.collage" handler:^(NSDictionary *params, WVPResponse *response) {
        [self collage:params response:response];
    }];
    [app handleCommand:@"BTImage.saveToPhotosAlbum" handler:^(id params, BTCallback callback) {
        [self _saveToPhotosAlbum:params callback:callback];
    }];
}

- (void)_saveToPhotosAlbum:(NSDictionary*)params callback:(BTCallback)callback {
    NSData* data = [BTCache get:params[@"url"] cacheInMemory:params[@"memory"]];
    if (!data.length) { return callback(@"Image has not been downloaded", nil); }
    UIImageWriteToSavedPhotosAlbum([UIImage imageWithData:data], nil, nil, nil);
    callback(nil,nil);
}

- (void)withResource:(NSString*)resourceUrl handler:(void(^)(id err, NSData* resource))handler {
    NSData* cached = [BTCache get:resourceUrl];
    if (cached) {
        handler(nil, cached);
    } else {
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:resourceUrl]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
            if (netErr || !netData) { return handler(@"Could not get image", nil); }
            
            [BTCache store:resourceUrl data:netData];
            handler(nil, netData);
        }];
    }
}

- (void)collage:(NSDictionary*)params response:(WVPResponse*)res {
    NSArray* rects = [params objectForKey:@"rects"];
    NSArray* contents = [params objectForKey:@"contents"];
    CGFloat alpha = [[params objectForKey:@"alpha"] floatValue];
    
    // Fetch images
    [contents parallel:contents.count
                map:^(NSString* resource, NSUInteger index, HHAsyncYieldResult yield) {
                    if ([resource hasPrefix:@"http"]) {
                        [self withResource:resource handler:^(id err, NSData *resourceData) {
                            if (err) { return yield(err, nil); }
                            UIImage* image = [UIImage imageWithData:resourceData];
                            yield(nil, image ? image : nil);
                        }];
                    } else {
                        yield(nil, resource);
                    }
                } finish:^(id error, NSMutableArray *results) {
                    UIGraphicsBeginImageContextWithOptions(([[params objectForKey:@"size"] makeSize]), YES, 0.0);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    [rects enumerateObjectsUsingBlock:^(NSString* rectString, NSUInteger idx, BOOL *stop) {
                        id content = [results objectAtIndex:idx];
                        CGRect rect = [rectString makeRect];
                        if ([content class] == [UIImage class]) {
                            [[(UIImage*)content thumbnailSize:rect.size transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault] drawAtPoint:rect.origin];
                        } else {
                            UIColor* color = [content makeRgbColor];
                            CGContextSetFillColorWithColor(context, [color CGColor]);
                            CGContextFillRect(context, [rectString makeRect]);
                        }
                    }];
                    UIImage* collageImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    [res respondWithImage:[collageImage imageWithAlpha:alpha] mimeType:@"image/jpg"];
                }
     ];
    
}


- (void)fetchImage:(NSDictionary*)params response:(WVPResponse *)res {
    if (params[@"mediaModule"]) {
        [BTModule module:params[@"mediaModule"] getMedia:params[@"mediaId"] callback:^(id error, id responseData) {
            [self processData:responseData params:params response:res];
        }];
        return;
    }
    
    NSString* file = [BTFiles path:params];
    if (file) {
        NSData* data = [NSData dataWithContentsOfFile:file];
        [self processData:data params:params response:res];
        return;
    }
    
    if (!params[@"store"]) {
        [self _fetchImageData:params response:res];
        return;
    }
    
    NSData* cachedProcessed = [BTCache get:res.request.URL.absoluteString cacheInMemory:params[@"memory"]];
    if (cachedProcessed) {
        [self respondWithData:cachedProcessed response:res params:params];
        return;
    }
    
    NSData* cachedOriginal = [BTCache get:params[@"url"] cacheInMemory:params[@"memory"]];
    if (cachedOriginal) {
        [self processData:cachedOriginal params:params response:res];
        return;
    }
    
    [self _fetchImageData:params response:res];
}

- (void)_fetchImageData:(NSDictionary*)params response:(WVPResponse*)res {
    NSString* urlParam = params[@"url"];
    @synchronized(loading) {
        if (loading[urlParam]) {
            [loading[urlParam] addObject:res];
            return;
        }
        loading[urlParam] = [NSMutableArray arrayWithObject:res];
    }
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlParam]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
        if (!netData) { return [res respondWithError:500 text:@"Error getting image :("]; }
        if (netData.length && params[@"store"]) {
            [BTCache store:urlParam data:netData cacheInMemory:params[@"memory"]];
        }
        NSArray* responses;
        @synchronized(loading) {
            responses = loading[urlParam];
            [loading removeObjectForKey:urlParam];
        }
        
        for (WVPResponse* res in responses) {
            [self processData:netData params:params response:res];
        }
    }];
}

- (void)processData:(NSData*)data params:(NSDictionary*)params response:(WVPResponse*)res {
    NSString* absoluteUrl = res.request.URL.absoluteString;
    @synchronized(processing) {
        if (processing[absoluteUrl]) {
            [processing[absoluteUrl] addObject:res];
            return;
        }
        processing[absoluteUrl] = [NSMutableArray arrayWithObject:res];
    }

    NSString* resizeParam = [params objectForKey:@"resize"];
    NSString* cropParam = [params objectForKey:@"crop"];
    NSData* resultData;
    if (resizeParam) {
        NSString* radiusParam = [params objectForKey:@"radius"];
        int radius = radiusParam ? [radiusParam intValue] : 0;
        UIImage* image = [UIImage imageWithData:data];
        image = [image thumbnailSize:[resizeParam makeSize] transparentBorder:0 cornerRadius:radius interpolationQuality:kCGInterpolationDefault];
        resultData = UIImageJPEGRepresentation(image, 1.0);
        if (params[@"store"] && resultData.length) {
            [BTCache store:res.request.URL.absoluteString data:resultData cacheInMemory:params[@"memory"]];
        }
    } else if (cropParam) {
        CGSize size = [cropParam makeSize];
        UIImage* image = [UIImage imageWithData:data];
        CGSize deltaSize = CGSizeMake(image.size.width - size.width, image.size.height - size.height);
        CGRect cropRect = CGRectMake(deltaSize.width / 2, deltaSize.height / 2, size.width, size.height);
        image = [image croppedImage:cropRect];
        resultData = UIImageJPEGRepresentation(image, 1.0);
        if (params[@"store"] && resultData.length) {
            [BTCache store:res.request.URL.absoluteString data:resultData cacheInMemory:params[@"memory"]];
        }
    } else {
        resultData = data;
    }
    
    NSArray* responses;
    @synchronized(processing) {
        responses = processing[absoluteUrl];
        [processing removeObjectForKey:absoluteUrl];
    }
    
    for (WVPResponse* res in responses) {
        [self respondWithData:resultData response:res params:params];
    }
}

- (void)respondWithData:(NSData *)data response:(WVPResponse *)res params:(NSDictionary *)params {
    NSString* mimeTypeParam = [params objectForKey:@"mimeType"];
    if (!mimeTypeParam) { mimeTypeParam = @"image/jpg"; }
    res.cachePolicy = NSURLCacheStorageNotAllowed; // we take care of caching ourselves
    [res respondWithData:data mimeType:mimeTypeParam];
}
@end