#import "BTNet.h"
#import "BTCache.h"
#import "BTFiles.h"
#import "BTAddressBook.h"
#import "Base64.h"
#import "BTImage.h"

@implementation BTNet

static NSOperationQueue* queue;
static BTNet* instance;


- (void)setup {
    if (instance) { return; }
    instance = self;
    queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:5];
    
    [BTApp handleCommand:@"BTNet.post" handler:^(id params, BTCallback callback) {
        [self _upload:params callback:callback];
    }];
}

- (void) _upload:(NSDictionary*)params callback:(BTCallback)callback {
    NSDictionary* attachmentsInfo = params[@"attachments"];
    NSMutableDictionary* attachments = [NSMutableDictionary dictionaryWithCapacity:attachmentsInfo.count];
    for (NSString* name in attachmentsInfo) {
        NSDictionary* info = attachmentsInfo[name];
        NSData* data;

        NSString* file = [BTFiles path:info];
        if (file) {
            data = [NSData dataWithContentsOfFile:file];
            
        } else if (info[@"data"]) {
            NSString* dataString = info[@"data"];
            data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
            
//        } else if (info[@"BTAddressBookRecordId"]) { // HACK
//            if (info[@"resize"]) {
//                NSString* resize = info[@"resize"];
//                NSData* imageData = [BTAddressBook getRecordImage:info[@"BTAddressBookRecordId"]];
//                BTImage* image = [BTImage imageWithData:imageData];
////                image = [image thumbnailSize:[resize makeSize] transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault];
//                imageData = UIImageJPEGRepresentation(image, 1.0);
//                data = imageData;
//            } else {
//                data = [BTAddressBook getRecordImage:info[@"BTAddressBookRecordId"]];
//            }
        
        } else if (info[@"base64Data"]) {
            NSString* base64String = [info[@"base64Data"] stringByReplacingOccurrencesOfString:@"data:image/jpeg;base64," withString:@""];
            data = [NSData dataWithBase64EncodedString:base64String];
//            if (info[@"saveToAlbum"]) {
//                UIImageWriteToSavedPhotosAlbum([UIImage imageWithData:data], nil, nil, nil);
//            }
            
        } else {
            NSLog(@"Warning: unknown attachment into %@", info);
        }
        
        if (data) {
            attachments[name] = data;
        } else {
            callback([@"Attachment with 0 data: " stringByAppendingString:name], nil);
        }
    }
    [BTNet post:params[@"url"] jsonParams:params[@"jsonParams"] attachments:attachments headers:params[@"headers"] boundary:params[@"boundary"] responseCallback:callback];

}

+ (void)request:(NSDictionary *)data responseCallback:(BTCallback)responseCallback {
    NSString* url = [data objectForKey:@"url"];
    NSString* method = [data objectForKey:@"method"];
    NSDictionary* postParams = [data objectForKey:@"params"];
    NSDictionary* headers = [data objectForKey:@"headers"];
    
    [BTNet request:url method:method headers:headers params:postParams responseCallback:responseCallback];
}

+ (void)post:(NSString*)url jsonParams:(NSDictionary*)jsonParams attachments:(NSDictionary*)attachments headers:(NSDictionary*)headers boundary:(NSString*)boundary responseCallback:(BTCallback)responseCallback {
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:jsonParams options:0 error:nil];
    NSDictionary* jsonPart = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"attachment; name=\"jsonParams\"", @"Content-Disposition",
                              @"application/json", @"Content-Type",
                              jsonData, @"data",
                              nil];
    
    NSMutableArray* parts = [NSMutableArray arrayWithObject:jsonPart];
    if (attachments) {
        for (NSString* name in attachments) {
            NSData* attachmentData = [attachments objectForKey:name];
            [parts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                              [NSString stringWithFormat:@"form-data; name=\"%@\" filename=\"%@\"", name, name], @"Content-Disposition" ,
                              @"application/octet-stream", @"Content-Type",
                              attachmentData, @"data",
                              nil]];
        }
    }
    
    [BTNet postMultipart:url headers:headers parts:parts boundary:boundary responseCallback:responseCallback];
}

+ (void)postMultipart:(NSString *)url headers:(NSDictionary *)headers parts:(NSArray *)parts boundary:(NSString*)boundary responseCallback:(BTCallback)responseCallback {
    
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
    [BTNet request:url method:@"POST" headers:headers data:httpData responseCallback:responseCallback];
}

+ (void)request:(NSString *)url method:(NSString *)method headers:(NSDictionary *)headers params:(NSDictionary *)params responseCallback:(BTCallback)responseCallback {
    NSData* data = nil;
    if (params) {
        data = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
        NSMutableDictionary* _headers = [NSMutableDictionary dictionaryWithDictionary:headers];
        [_headers setObject:@"application/json" forKey:@"Content-Type"];
        headers = _headers;
    }
    [BTNet request:url method:method headers:headers data:data responseCallback:responseCallback];
}

+ (void)request:(NSString*)url method:(NSString*)method headers:(NSDictionary*)headers data:(NSData*)data responseCallback:(BTCallback)responseCallback {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = method;

    if (data) {
        request.HTTPBody = data;
        NSMutableDictionary* _headers = [NSMutableDictionary dictionaryWithDictionary:headers];
        [_headers setObject:[NSString stringWithFormat:@"%d", request.HTTPBody.length] forKey:@"Content-Length"];
        headers = _headers;
    }
    
    for (NSString* headerName in headers) {
        id headerValue = headers[headerName];
        if (![headerValue isKindOfClass:[NSString class]]) {
            NSLog(@"WARNING bad header value type %@ %@", headerName, headerValue);
            continue;
        }
        [request setValue:headerValue forHTTPHeaderField:headerName];
    }

    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *netRes, NSData *netData, NSError *netErr) {
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
