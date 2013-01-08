//
//  BTImage.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import "BTImage.h"
#import "UIImage+Resize.h"

@interface BTImage (hidden)
- (void) fetchImage:(NSURLRequest*)req response:(WVPResponse*)res;
- (void) respondWithData:(NSData*)data response:(WVPResponse*)res params:(NSDictionary*)params;
@end

@implementation BTImage {
    NSOperationQueue* queue;
}

- (id)init {
    if (self = [super init]) {
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 5;
    }
    return self;
}

- (void)setup:(BTAppDelegate *)app {
    [WebViewProxy handleRequestsWithHost:app.serverHost path:@"/BTImage/fetchImage" handler:^(NSURLRequest *req, WVPResponse *res) {
        [self fetchImage:req response:res];
    }];
}
@end

static NSString* cacheBucket = @"__BTImage__";

@implementation BTImage (hidden)

- (void)fetchImage:(NSURLRequest *)req response:(WVPResponse *)res {
    NSDictionary* params = [self parseQueryParams:req.URL.query];

    bool useCache = !![params objectForKey:@"cache"];
    if (useCache) {
//        UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
//        bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
//            [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
//        }];
        if ([BTAppDelegate.instance.cache has:cacheBucket key:req.URL.absoluteString]) {
            NSData* cachedProcessedData = [BTAppDelegate.instance.cache get:cacheBucket key:req.URL.absoluteString];
            [self respondWithData:cachedProcessedData response:res params:params];
        } else if ([BTAppDelegate.instance.cache has:cacheBucket key:[params objectForKey:@"url"]]) {
            NSData* cachedNetData = [BTAppDelegate.instance.cache get:cacheBucket key:[params objectForKey:@"url"]];
            [self processData:cachedNetData request:req response:res params:params];
        } else {
            [self fetchData:req response:res params:params];
        }
    } else {
        [self fetchData:req response:res params:params];
    }
}

- (void)fetchData:(NSURLRequest *)req response:(WVPResponse*)res params:(NSDictionary*)params {
    NSString* urlParam = [params objectForKey:@"url"];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlParam]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
        if (!netData) { return [res respondWithError:500 text:@"Error getting image :("]; }
        [self processData:netData request:req response:res params:params];
    }];
}

- (void)processData:(NSData*)netData request:(NSURLRequest*)req response:(WVPResponse*)res params:(NSDictionary*)params {
    bool useCache = !![params objectForKey:@"cache"];
    if (useCache) {
        [BTAppDelegate.instance.cache store:cacheBucket key:[params objectForKey:@"url"] data:netData];
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
            [BTAppDelegate.instance.cache store:cacheBucket key:req.URL.absoluteString data:resizedData];
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
            [BTAppDelegate.instance.cache store:cacheBucket key:req.URL.absoluteString data:croppedData];
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