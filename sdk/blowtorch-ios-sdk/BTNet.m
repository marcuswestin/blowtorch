#import "BTNet.h"

@implementation BTNet

@synthesize engine;

- (id)init {
    if (self = [super init]) {
        self.engine = [[MKNetworkEngine alloc] initWithHostName:nil customHeaderFields:nil];
    }
    return self;
}

- (void) cache:(NSString*)url override:(BOOL)override asUrl:(NSString*)asUrl responseCallback:(ResponseCallback)responseCallback {
    if (!asUrl) { asUrl = url; }
    
    NSLog(@"Cache request %@ as %@", url, asUrl);
    
    NSString *filePath = [BTNet pathForUrl:asUrl];
    
    if (!override && [[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSLog(@"FOUND URL IN CACHE %@ %@", asUrl, filePath);
        responseCallback(nil, nil);
    } else {
        MKNetworkOperation* operation = [engine operationWithURLString:url];
        [operation onCompletion:^(MKNetworkOperation *completedOperation) {
            [completedOperation.responseData writeToFile:filePath atomically:YES];
            NSLog(@"Cached %@ as %@", url, asUrl);
            responseCallback(nil, nil);
        } onError:^(NSError *error) {
            NSLog(@"ERROR GETTING URL %@ %@", url, error);
            responseCallback(@"Error getting url", nil);
        }];
        [engine enqueueOperation:operation];
    }
    
}


+ (NSString *)urlEncodeValue:(NSString *)str {
    NSString* res = (__bridge NSString*) CFURLCreateStringByAddingPercentEscapes(
                                                   NULL,
                                                   (__bridge CFStringRef)str,
                                                   NULL,
                                                   (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                   kCFStringEncodingUTF8 );
    return res;
}

+ (NSString *)pathForUrl:(NSString *)url {
    NSString* fileName = [BTNet urlEncodeValue:url];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths objectAtIndex:0];
    BOOL isDir = NO;
    NSError *error;
    if (! [[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:&error];
    }
    return [cachePath stringByAppendingPathComponent:fileName];
}

+ (void)request:(NSString*)url method:(NSString*)method headers:(NSDictionary *)headers  params:(NSDictionary*)params responseCallback:(ResponseCallback)responseCallback {
    MKNetworkEngine* netEngine = [[MKNetworkEngine alloc] initWithHostName:nil customHeaderFields:headers];
    MKNetworkOperation* op = [netEngine operationWithURLString:url params:[NSMutableDictionary dictionaryWithDictionary:params] httpMethod:method];
    [op onCompletion:^(MKNetworkOperation* completedOperation) {
        responseCallback(nil, [NSDictionary dictionaryWithObject:[completedOperation responseData] forKey:@"responseData"]);
    } onError:^(NSError* error) {
        responseCallback(error, nil);
    }];
    [netEngine enqueueOperation:op];
}

@end
