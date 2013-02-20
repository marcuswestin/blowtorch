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
    [WebViewProxy handleRequestsWithHost:app.serverHost path:@"/BTImage/fetchImage" handler:^(NSURLRequest *req, WVPResponse *res) {
        [self fetchImage:req.URL.absoluteString params:[req.URL.query parseQueryParams] response:res];
    }];
    [WebViewProxy handleRequestsWithHost:app.serverHost path:@"/BTImage/collage" handler:^(NSURLRequest *req, WVPResponse *res) {
        [self collage:req.URL.absoluteString params:[req.URL.query parseQueryParams] response:res];
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

- (void)collage:(NSString*)requestUrl params:(NSDictionary*)params response:(WVPResponse*)res {
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
                            [[(UIImage*)content thumbnailSize:rect.size transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationHigh] drawAtPoint:rect.origin];
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


- (void)fetchImage:(NSString *)requestUrl params:(NSDictionary*)params response:(WVPResponse *)res {
    bool useCache = !![params objectForKey:@"cache"];
    
    if (useCache) {
//        UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
//        bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
//            [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
//        }];
        if ([BTCache has:requestUrl]) {
            [self respondWithData:[BTCache get:requestUrl] response:res params:params];
        } else if ([BTCache has:[params objectForKey:@"url"]]) {
            NSData* cachedNetData = [BTCache get:[params objectForKey:@"url"]];
            [self processData:cachedNetData requestUrl:requestUrl response:res params:params];
        } else {
            [self fetchData:requestUrl response:res params:params];
        }
    } else {
        [self fetchData:requestUrl response:res params:params];
    }
}

- (void)fetchData:(NSString *)requestUrl response:(WVPResponse*)res params:(NSDictionary*)params {
    NSString* urlParam = [params objectForKey:@"url"];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlParam]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
        if (!netData) { return [res respondWithError:500 text:@"Error getting image :("]; }
        [self processData:netData requestUrl:requestUrl response:res params:params];
    }];
}

- (void)processData:(NSData*)netData requestUrl:(NSString*)requestUrl response:(WVPResponse*)res params:(NSDictionary*)params {
    bool useCache = !![params objectForKey:@"cache"];
    if (useCache) {
        [BTCache store:[params objectForKey:@"url"] data:netData];
    }
    
    NSString* resizeParam = [params objectForKey:@"resize"];
    NSString* cropParam = [params objectForKey:@"crop"];
    
    if (resizeParam) {
        NSString* radiusParam = [params objectForKey:@"radius"];
        int radius = radiusParam ? [radiusParam intValue] : 0;
        CGSize size = [self getSize:resizeParam];
        UIImage* image = [UIImage imageWithData:netData];
        image = [image thumbnailSize:size transparentBorder:0 cornerRadius:radius interpolationQuality:kCGInterpolationDefault];
        // kCGInterpolationHigh
        NSData* resizedData = UIImageJPEGRepresentation(image, 1.0);
//        NSData* resizedData = UIImagePNGRepresentation(image);
        if (useCache) {
            [BTCache store:requestUrl data:resizedData];
        }
        [self respondWithData:resizedData response:res params:params];
    } else if (cropParam) {
        CGSize size = [self getSize:cropParam];
        UIImage* image = [UIImage imageWithData:netData];
        CGSize deltaSize = CGSizeMake(image.size.width - size.width, image.size.height - size.height);
        CGRect cropRect = CGRectMake(deltaSize.width / 2, deltaSize.height / 2, size.width, size.height);
        image = [image croppedImage:cropRect];
        NSData* croppedData = UIImageJPEGRepresentation(image, 1.0);
        if (useCache) {
            [BTCache store:requestUrl data:croppedData];
        }
        [self respondWithData:croppedData response:res params:params];
    } else {
        [self respondWithData:netData response:res params:params];
    }
}

- (CGSize) getSize:(NSString*)sizeParam {
    NSArray* sizes = [sizeParam componentsSeparatedByString:@"x"];
    return CGSizeMake([sizes[0] integerValue], [sizes[1] integerValue]);
}

- (void)respondWithData:(NSData *)data response:(WVPResponse *)res params:(NSDictionary *)params {
    NSString* mimeTypeParam = [params objectForKey:@"mimeType"];
    [res respondWithData:data mimeType:mimeTypeParam];
}
@end