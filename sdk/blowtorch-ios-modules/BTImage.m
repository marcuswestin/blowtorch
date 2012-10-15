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
- (void) fetchImage:(NSURLRequest*)req res:(WVPResponse*)res;
@end

@implementation BTImage
- (void)setup:(BTAppDelegate *)app {
    [WebViewProxy handleRequestsWithHost:@"blowtorch" path:@"/BTImage/fetchImage" handler:^(NSURLRequest *req, WVPResponse *res) {
        [self fetchImage:req res:res];
    }];
}
@end

@implementation BTImage (hidden)
- (void)fetchImage:(NSURLRequest *)req res:(WVPResponse *)res {
    NSDictionary* params = [self parseQueryParams:req.URL.query];
    NSString* urlParam = [params objectForKey:@"url"];
    NSString* cacheParam = [params objectForKey:@"cache"];
    NSString* mimeTypeParam = [params objectForKey:@"mimeType"];
    bool cache = [cacheParam isEqualToString:@"cache"];
    if (cache) {
        NSData* cacheData = [BTAppDelegate.instance.cache get:@"BTImage" key:urlParam];
        if (cacheData) {
            [res respondWithImage:[UIImage imageWithData:cacheData]];
            return;
        }
    }
    NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlParam]];
    UIImage* image = [UIImage imageWithData:data];

    NSString* resizeParam = [params objectForKey:@"resize"];
    NSLog(@"BTImage TODO handle resizeParam %@", resizeParam);
    if (true) {
        // kCGInterpolationHigh
        image = [image thumbnailImage:50 transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault];
    }

    if (cache) {
        [BTAppDelegate.instance.cache store:@"BTImage" key:urlParam data:data];
    }
    [res respondWithImage:image mimeType:mimeTypeParam];
}
@end