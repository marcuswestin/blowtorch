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
    NSString* urlParam = [params objectForKey:@"url"];
    bool cache = !![params objectForKey:@"cache"];

    if (cache) {
        if ([BTAppDelegate.instance.cache has:cacheBucket key:urlParam]) {
            UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
            bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
            }];
            [self respondWithData:[BTAppDelegate.instance.cache get:cacheBucket key:urlParam] response:res params:params];
            return;
        }
    }
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlParam]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
        if (!netData) { return [res respondWithError:500 text:@"Error getting image :("]; }
        if (cache) {
            [BTAppDelegate.instance.cache store:cacheBucket key:urlParam data:netData];
        }
        [self respondWithData:netData response:res params:params];
    }];
}

- (void)respondWithData:(NSData *)data response:(WVPResponse *)res params:(NSDictionary *)params {
    NSString* mimeTypeParam = [params objectForKey:@"mimeType"];
    NSString* resizeParam = [params objectForKey:@"resize"];
    UIImage* image = [UIImage imageWithData:data];
    if (resizeParam) {
        NSArray* sizes = [resizeParam componentsSeparatedByString:@"x"];
        CGSize size = CGSizeMake([sizes[0] integerValue], [sizes[1] integerValue]);
        image = [image thumbnailSize:size transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault];
        // kCGInterpolationHigh
    }
    [res respondWithImage:image mimeType:mimeTypeParam];
}
@end