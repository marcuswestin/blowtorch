#import "BTNet.h"
#import "WebViewJavascriptBridge.h"
#import "BTCache.h"
#import "BTAppDelegate.h"

@implementation BTNet

static NSOperationQueue* queue;

- (id)init {
    if (self = [super init]) {
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:5];
    }
    return self;
}

//static NSString* cacheBucket = @"__BTNet__";
//- (void) cache:(NSString*)url override:(BOOL)override asUrl:(NSString*)asUrl responseCallback:(WVJBResponseCallback)responseCallback {
//    if (!asUrl) { asUrl = url; }
//    
//    NSLog(@"Cache request %@ as %@", url, asUrl);
//    
//    if (!override && [BTAppDelegate.instance.cache has:cacheBucket key:[BTNet urlEncodeValue:asUrl]]) {
//        NSLog(@"FOUND URL IN CACHE %@ %@", url, asUrl);
//        responseCallback(nil, nil);
//    } else {
//        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
//            if (netErr || ((NSHTTPURLResponse*)netRes).statusCode >= 300) {
//                NSLog(@"ERROR GETTING URL %@", url);
//                return responseCallback(@"Error getting url", nil);
//            }
//            [BTAppDelegate.instance.cache store:cacheBucket key:asUrl data:netData];
//            NSLog(@"Cached %@ as %@", url, asUrl);
//            responseCallback(nil, nil);
//        }];
//    }
//}


+ (void)request:(NSString *)url method:(NSString *)method headers:(NSDictionary *)headers params:(NSDictionary *)params responseCallback:(WVJBResponseCallback)responseCallback {
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
        if (netErr || ((NSHTTPURLResponse*)netRes).statusCode >= 300) { return responseCallback(@"Could not load", nil); }
        NSDictionary* responseData = [NSJSONSerialization JSONObjectWithData:netData options:NSJSONReadingAllowFragments error:nil];
        responseCallback(nil, [NSDictionary dictionaryWithObject:responseData forKey:@"responseData"]);
    }];
}

@end
