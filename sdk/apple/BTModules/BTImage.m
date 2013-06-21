//
//  BTImage.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTImage.h"
#import "BTFiles.h"
#import "BTCache.h"
#import "NSString+BTUtils.h"

@implementation BTImage {
    NSOperationQueue* queue;
    NSMutableDictionary* loading;
    NSMutableDictionary* processing;
}

static BTImage* instance;

- (void)setup {
    instance = self;
    loading = [NSMutableDictionary dictionary];
    processing = [NSMutableDictionary dictionary];
    queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 10;
    [BTApp handleRequests:@"BTImage.fetchImage" handler:^(NSDictionary *params, WVPResponse *response) {
        [self fetchImage:params response:response];
    }];
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

//- (void)collage:(NSDictionary*)params response:(WVPResponse*)res {
//    NSArray* rects = [params objectForKey:@"rects"];
//    NSArray* contents = [params objectForKey:@"contents"];
//    CGFloat alpha = [[params objectForKey:@"alpha"] floatValue];
//    
//    // Fetch images
//    [contents parallel:contents.count
//                map:^(NSString* resource, NSUInteger index, HHAsyncYieldResult yield) {
//                    if ([resource hasPrefix:@"http"]) {
//                        [self withResource:resource handler:^(id err, NSData *resourceData) {
//                            if (err) { return yield(err, nil); }
//                            UIImage* image = [UIImage imageWithData:resourceData];
//                            yield(nil, image ? image : nil);
//                        }];
//                    } else {
//                        yield(nil, resource);
//                    }
//                } finish:^(id error, NSMutableArray *results) {
//                    UIGraphicsBeginImageContextWithOptions(([[params objectForKey:@"size"] makeSize]), YES, 0.0);
//                    CGContextRef context = UIGraphicsGetCurrentContext();
//                    [rects enumerateObjectsUsingBlock:^(NSString* rectString, NSUInteger idx, BOOL *stop) {
//                        id content = [results objectAtIndex:idx];
//                        CGRect rect = [rectString makeRect];
//                        if ([content class] == [UIImage class]) {
//                            [[(UIImage*)content thumbnailSize:rect.size transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault] drawAtPoint:rect.origin];
//                        } else {
//                            UIColor* color = [content makeRgbColor];
//                            CGContextSetFillColorWithColor(context, [color CGColor]);
//                            CGContextFillRect(context, [rectString makeRect]);
//                        }
//                    }];
//                    UIImage* collageImage = UIGraphicsGetImageFromCurrentImageContext();
//                    UIGraphicsEndImageContext();
//                    [res respondWithImage:[collageImage imageWithAlpha:alpha] mimeType:@"image/jpg"];
//                }
//     ];
//    
//}


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
    
    NSData* cachedProcessed = [BTCache get:res.request.URL.absoluteString cacheInMemory:!!params[@"memory"]];
    if (cachedProcessed) {
        [self respondWithData:cachedProcessed response:res params:params];
        return;
    }
    
    NSData* cachedOriginal = [BTCache get:params[@"url"] cacheInMemory:!!params[@"memory"]];
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
            [BTCache store:urlParam data:netData cacheInMemory:!!params[@"memory"]];
        }
//        NSArray* responses;
//        @synchronized(loading) {
//            responses = loading[urlParam];
//            [loading removeObjectForKey:urlParam];
//        }
//        
//        for (WVPResponse* res in responses) {
//            [self processData:netData params:params response:res];
//        }
        [self processData:netData params:params response:res];
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

    BOOL cache = NO;
    
    if (params[@"resize"]) {
        data = [BTImage resize:[BTImage imageWithData:data] size:[params[@"resize"] makeSize]];
        cache = YES;
    }
    
    if (params[@"crop"]) {
        data = [BTImage crop:[BTImage imageWithData:data] size:[params[@"crop"] makeSize]];
        cache = YES;
    }

    if (params[@"store"] && cache && data.length != 0) {
        [BTCache store:res.request.URL.absoluteString data:data cacheInMemory:!!params[@"memory"]];
    }

    NSArray* responses;
    @synchronized(processing) {
        responses = processing[absoluteUrl];
        [processing removeObjectForKey:absoluteUrl];
    }
    
    for (WVPResponse* res in responses) {
        [self respondWithData:data response:res params:params];
    }

//    [self respondWithData:data response:res params:params];
}

#if defined BT_PLATFORM_IOS

+ (UIImage *)imageWithData:(NSData *)data {
    return [UIImage imageWithData:data];
}

+ (NSData *)resize:(UIImage *)image size:(CGSize)size {
    image = [image thumbnailSize:size transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault];
    return UIImageJPEGRepresentation(image, 1.0);    
}

+ (NSData *)crop:(UIImage *)image size:(CGSize)size {
    CGRect rect = CGRectMake((image.size.width - size.width) / 2, (image.size.height - size.height) / 2, size.width, size.height);
    return [BTImage crop:image rect:rect];
}

+ (NSData *)crop:(UIImage *)image rect:(CGRect)rect {
    image = [image croppedImage:rect];
    return UIImageJPEGRepresentation(image, 1.0);
}

#elif defined BT_PLATFORM_OSX

+ (NSImage *)imageWithData:(NSData *)data {
    return [[NSImage alloc] initWithData:data];
}

+ (NSData *)resize:(NSImage *)image size:(CGSize)size {
    NSSize originalSize = [image size];
    NSImage* target = [[NSImage alloc] initWithSize:size];
    [target lockFocus];
    [image drawInRect:NSMakeRect(0,0,size.width,size.height) fromRect:NSMakeRect(0,0,originalSize.width,originalSize.height) operation:NSCompositeSourceOver fraction:1.0];
    [target unlockFocus];
    return [target TIFFRepresentation];
//    NSArray *representations = [target representations];
//    NSNumber *compressionFactor = [NSNumber numberWithFloat:0.9];
//    NSDictionary *imageProps = @{ NSImageCompressionFactor:compressionFactor };
//    return [NSBitmapImageRep representationOfImageRepsInArray:representations usingType:NSJPEGFileType properties:imageProps];
}

+ (NSData *)crop:(NSImage *)source size:(CGSize)size {
    CGRect rect = CGRectMake((source.size.width - size.width) / 2, (source.size.height - size.height) / 2, size.width, size.height);
    return [BTImage crop:source rect:rect];
}

+ (NSData *)crop:(NSImage *)source rect:(CGRect)rect {
    NSImage* target = [[NSImage alloc] initWithSize:rect.size];
    [target lockFocus];
    [source drawInRect:NSMakeRect(0, 0, rect.size.width, rect.size.height) fromRect:rect operation:NSCompositeCopy fraction:1.0];
    [target unlockFocus];
    NSBitmapImageRep *bmpImageRep = [[NSBitmapImageRep alloc]initWithData:[target TIFFRepresentation]];
    [target addRepresentation:bmpImageRep];
    return [bmpImageRep representationUsingType:NSPNGFileType properties: nil];
}

#endif

- (void)respondWithData:(NSData *)data response:(WVPResponse *)res params:(NSDictionary *)params {
    NSString* mimeTypeParam = [params objectForKey:@"mimeType"];
    if (!mimeTypeParam) { mimeTypeParam = @"image/jpg"; }
    res.cachePolicy = NSURLCacheStorageNotAllowed; // we take care of caching ourselves
    [res respondWithData:data mimeType:mimeTypeParam];
}
@end