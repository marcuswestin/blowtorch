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
}

static BTImage* instance;

- (id)init {
    if (self = [super init]) {
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 5;
    }
    return self;
}

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    [app handleRequests:@"BTImage.fetchImage" handler:^(NSDictionary *params, WVPResponse *response) {
        [self fetchImage:params response:response];
    }];
    [app handleRequests:@"BTImage.collage" handler:^(NSDictionary *params, WVPResponse *response) {
        [self collage:params response:response];
    }];
}

- (void)withResource:(NSString*)resourceUrl handler:(void(^)(id err, NSData* resource))handler {
    if ([BTCache has:resourceUrl]) {
        handler(nil, [BTCache get:resourceUrl]);
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
    NSLog(@"BTImage.fetchImage %@", params);
    if (params[@"mediaModule"]) {
        [BTModule module:params[@"mediaModule"] getMedia:params[@"mediaId"] callback:^(id error, id responseData) {
            [self processData:responseData params:params response:res];
        }];
        return;
    }
    
    if (params[@"document"]) {
        [self async:^{
            NSData* data = [BTFiles readDocument:params[@"document"]];
            [self processData:data params:params response:res];
        }];
        return;
    }
    
    if (params[@"file"]) {
        [self async:^{
            NSData* data = [NSData dataWithContentsOfFile:params[@"file"]];
            [self processData:data params:params response:res];
        }];
        return;
    }
    
    if (![params objectForKey:@"cache"]) {
        [self _fetchImageData:params response:res];
        return;
    }
    
//    UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
//    bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
//        [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
//    }];
    if ([BTCache has:params[@"url"]]) {
        if ([BTCache has:res.request.URL.absoluteString]) {
            [self respondWithData:[BTCache get:res.request.URL.absoluteString] response:res params:params];
            return;
        }
        NSData* cachedNetData = [BTCache get:params[@"url"]];
        [self processData:cachedNetData params:params response:res];
    } else {
        [self _fetchImageData:params response:res];
    }
}

- (void)_fetchImageData:(NSDictionary*)params response:(WVPResponse*)res {
    NSString* urlParam = params[@"url"];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlParam]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
        if (!netData) { return [res respondWithError:500 text:@"Error getting image :("]; }
        if (netData.length && params[@"cache"]) {
            [BTCache store:params[@"url"] data:netData];
        }
        [self processData:netData params:params response:res];
    }];
}

- (void)processData:(NSData*)data params:(NSDictionary*)params response:(WVPResponse*)res {
    NSString* resizeParam = [params objectForKey:@"resize"];
    NSString* cropParam = [params objectForKey:@"crop"];
    if (resizeParam) {
        NSString* radiusParam = [params objectForKey:@"radius"];
        int radius = radiusParam ? [radiusParam intValue] : 0;
        UIImage* image = [UIImage imageWithData:data];
        image = [image thumbnailSize:[resizeParam makeSize] transparentBorder:0 cornerRadius:radius interpolationQuality:kCGInterpolationDefault];
        data = UIImageJPEGRepresentation(image, 1.0);
        if (params[@"cache"] && data.length) {
            [BTCache store:res.request.URL.absoluteString data:data];
        }
    } else if (cropParam) {
        CGSize size = [cropParam makeSize];
        UIImage* image = [UIImage imageWithData:data];
        CGSize deltaSize = CGSizeMake(image.size.width - size.width, image.size.height - size.height);
        CGRect cropRect = CGRectMake(deltaSize.width / 2, deltaSize.height / 2, size.width, size.height);
        image = [image croppedImage:cropRect];
        data = UIImageJPEGRepresentation(image, 1.0);
        if (params[@"cache"]) {
            [BTCache store:res.request.URL.absoluteString data:data];
        }
    }
    [self respondWithData:data response:res params:params];
}

- (void)respondWithData:(NSData *)data response:(WVPResponse *)res params:(NSDictionary *)params {
    NSString* mimeTypeParam = [params objectForKey:@"mimeType"];
    res.cachePolicy = NSURLCacheStorageNotAllowed; // we take care of caching ourselves
    [res respondWithData:data mimeType:mimeTypeParam];
}
@end