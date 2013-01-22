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

+ (void)request:(NSDictionary *)data responseCallback:(BTResponseCallback)responseCallback {
    NSString* url = [data objectForKey:@"url"];
    NSString* method = [data objectForKey:@"method"];
    NSDictionary* postParams = [data objectForKey:@"params"];
    NSDictionary* headers = [data objectForKey:@"headers"];
    
    [BTNet request:url method:method headers:headers params:postParams responseCallback:responseCallback];
}

+ (void)post:(NSString*)url json:(NSDictionary*)params data:(NSData*)data headers:(NSDictionary*)headers boundary:(NSString*)boundary responseCallback:(id)responseCallback {
    NSDictionary* jsonPart = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"attachment; name=\"multipartParams\"", @"Content-Disposition",
                              @"application/json", @"Content-Type",
                              [NSJSONSerialization dataWithJSONObject:params options:0 error:nil], @"data",
                              nil];
    
    NSDictionary* dataPart = nil;
    if (data) {
        dataPart = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"form-data; name=\"data\" filename=\"data\"", @"Content-Disposition",
                    @"application/octet-stream", @"Content-Type",
                    data, @"data",
                    nil];
    }
    
    NSMutableArray* parts = [NSArray arrayWithObjects:jsonPart, dataPart, nil];
    [BTNet postMultipart:url headers:headers parts:parts boundary:boundary responseCallback:responseCallback];
}

+ (void)postMultipart:(NSString *)url headers:(NSDictionary *)headers parts:(NSArray *)parts boundary:(NSString*)boundary responseCallback:(BTResponseCallback)responseCallback {
    
    NSMutableDictionary* _headers = [NSMutableDictionary dictionaryWithDictionary:headers];
    [_headers setObject:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forKey:@"Content-Type"];
    headers = _headers;

    NSMutableData* httpData = [NSMutableData data];
    for (NSDictionary* part in parts) {
        NSData* data = [part valueForKey:@"data"];
        // BOUNDARY
        [httpData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        // HEADERS
        [httpData appendData:[[NSString stringWithFormat:@"Content-Disposition: %@\r\n", [part valueForKey:@"Content-Disposition"]] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpData appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n", [part valueForKey:@"Content-Type"]] dataUsingEncoding:NSUTF8StringEncoding]];
        // EMPTY
        [httpData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        // CONTENT + newline
        [httpData appendData:[NSData dataWithData:data]];
        [httpData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [httpData appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    NSLog(@"SEND %@", [[NSString alloc] initWithData:httpData encoding:NSUTF8StringEncoding]);
    [BTNet request:url method:@"POST" headers:headers data:httpData responseCallback:responseCallback];
}

+ (void)request:(NSString *)url method:(NSString *)method headers:(NSDictionary *)headers params:(NSDictionary *)params responseCallback:(BTResponseCallback)responseCallback {
    NSData* data = nil;
    if (params) {
        data = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
        NSMutableDictionary* _headers = [NSMutableDictionary dictionaryWithDictionary:headers];
        [_headers setObject:@"application/json" forKey:@"Content-Type"];
        headers = _headers;
    }
    [BTNet request:url method:method headers:headers data:data responseCallback:responseCallback];
}

+ (void)request:(NSString*)url method:(NSString*)method headers:(NSDictionary*)headers data:(NSData*)data responseCallback:(BTResponseCallback)responseCallback {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = method;

    if (data) {
        request.HTTPBody = data;
        NSMutableDictionary* _headers = [NSMutableDictionary dictionaryWithDictionary:headers];
        [_headers setObject:[NSString stringWithFormat:@"%d", request.HTTPBody.length] forKey:@"Content-Length"];
        headers = _headers;
    }
    
    for (NSString* headerName in headers) {
        [request setValue:[headers objectForKey:headerName] forHTTPHeaderField:headerName];
    }

    UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
    bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
    }];
    
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
        [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
        if (netErr || ((NSHTTPURLResponse*)netRes).statusCode >= 300) {
            NSString* errorMessage = netData ? [[NSString alloc] initWithData:netData encoding:NSUTF8StringEncoding] : @"Could not complete request";
            responseCallback(errorMessage, nil);
        } else {
            // Should inspect response content type and not assume application/json.
            NSDictionary* jsonData = nil;
            if (netData && netData.length) {
                jsonData = [NSJSONSerialization JSONObjectWithData:netData options:NSJSONReadingAllowFragments error:nil];
            }
            responseCallback(nil, jsonData);
        }
    }];
}

@end
