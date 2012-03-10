#import "BlowTorch.h"
#import "AFJSONUtilities.h"
#import "NSFileManager+Tar.h"

@interface BlowTorch (hidden)
- (NSData*) getUpgradeRequestBody;
- (NSDictionary*) getClientInfo;
- (NSDictionary*) storeClientInfo:(NSDictionary*)clientInfo;
- (NSString*) getClientInfoFilePath;
- (void) startVersionDownload:(NSString*)version;
- (NSURL*) getUrl:(NSString*) path;
- (NSString*) getFilePath:(NSString*) name;
@end

@implementation BlowTorch

@synthesize window, webView, javascriptBridge, interceptionCache;

/* API
 *****/
- (void) handleCommand:(NSString *)command data:(NSDictionary *)data responseCallback:(ResponseCallback)responseCallback {
    [NSException raise:@"BlowTorch abstract method" format:@" handleCommand:data:responseCallback must be overridden"];
}

/* Upgrade API
 *************/
- (void)requestUpgrade {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self getUrl:@"upgrade"]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self getUpgradeRequestBody]];
    [[AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary* upgradeResponse) {
        NSLog(@"upgrade response %@", upgradeResponse);
        NSDictionary* clientInfo = [upgradeResponse objectForKey:@"client_info"];
        [self storeClientInfo:clientInfo];
        NSString* newVersion = [upgradeResponse objectForKey:@"new_version"];
        if (newVersion) {
            [self startVersionDownload:newVersion];
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        NSLog(@"upgrade failure %@", error);
    }] start];
}

/* Webview messaging
 *******************/
- (void)javascriptBridge:(WebViewJavascriptBridge *)bridge receivedMessage:(NSString *)messageString fromWebView:(UIWebView *)fromWebView {
    NSDictionary* message = [messageString objectFromJSONString];
    NSString *callbackID = [message objectForKey:@"callbackID"];
    NSString *command = [message objectForKey:@"command"];
    NSDictionary *data = [message objectForKey:@"data"];

    if ([command isEqualToString:@"blowtorch:reload"]) {
        [self loadPage];
    } else if ([command isEqualToString:@"blowtorch:log"]) {
        NSLog(@"console.log %@", data);
    } else {
        [self handleCommand:command data:data responseCallback:^(NSString *errorMessage, NSDictionary *response) {
            NSLog(@"Send response to %@", command);
            NSDictionary* responseMessage = errorMessage
                ? [NSDictionary dictionaryWithObjectsAndKeys:callbackID, @"responseID", errorMessage, @"error", nil]
                : [NSDictionary dictionaryWithObjectsAndKeys:callbackID, @"responseID", response, @"data", nil];
            [javascriptBridge sendMessage:[responseMessage JSONString] toWebView:fromWebView];
        }];
    }
}

/* App lifecycle
 ***************/
- (void) loadPage {
    [webView loadHTMLString:
     @"<!doctype html>"
     "<html><head></head><body>"
     "<script src='http://localhost:3333/require/blowtorch/dev-tools'></script>"
     "<script src='http://localhost:3333/require/blowtorch/bootstrap-ios'></script>"
     "</body></html>" baseURL:nil];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // create window
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    screenBounds.origin.y += 10;
    screenBounds.size.height -= 20;
    window = [[UIWindow alloc] initWithFrame:screenBounds];
    window.backgroundColor = [UIColor whiteColor];
    [window makeKeyAndVisible];
    [window setRootViewController:[[UIViewController alloc] init]]; // every app should have a root view controller
    // create webview
    webView = [[UIWebView alloc] initWithFrame:screenBounds];
    [window addSubview:webView];
    javascriptBridge = [WebViewJavascriptBridge javascriptBridgeWithDelegate:self];
    webView.delegate = javascriptBridge;
    [self loadPage];

    interceptionCache = [[BlowTorchInterceptionCache alloc] init];
    [NSURLCache setSharedURLCache:interceptionCache];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /* Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state. Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game. */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    /* Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits. */
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    /* Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background. */
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /* Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface. */
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /* Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:. */
}

@end

@implementation BlowTorch (hidden)

- (NSData *)getUpgradeRequestBody {
    NSDictionary* requestObj = [NSDictionary dictionaryWithObject:[self getClientInfo] forKey:@"client_info"];
    NSError *error = nil;
    NSData *JSONData = AFJSONEncode(requestObj, &error);
    return error ? nil : JSONData;
}

- (NSDictionary *)getClientInfo {
    NSString* filePath = [self getClientInfoFilePath];
    NSDictionary* clientInfo = [NSDictionary dictionaryWithContentsOfFile:filePath];
    if (!clientInfo) {
        clientInfo = [NSDictionary dictionary];
    }
    return clientInfo;
}

- (NSDictionary *)storeClientInfo:(NSDictionary*)newClientInfo {
    NSString* filePath = [self getClientInfoFilePath];
    NSMutableDictionary *currentClientInfo = [NSMutableDictionary dictionaryWithDictionary:[self getClientInfo]];
    for (NSString* key in newClientInfo) {
        [currentClientInfo setValue:[newClientInfo valueForKey:key] forKey:key];
    }
    [currentClientInfo writeToFile:filePath atomically:YES];
    return currentClientInfo;
}

- (NSString *)getClientInfoFilePath {
    return [self getFilePath:@"blowtorch-client_info-1"];
}

- (NSString *)getFilePath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

- (void)startVersionDownload:(NSString *)version {
    NSLog(@"Start download %@", version);
    [[NSFileManager defaultManager] createDirectoryAtPath:[self getFilePath:@"archives"] withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL* payloadUrl = [self getUrl:[NSString stringWithFormat:@"builds/%@", version]];
    NSString* tarFilePath = [self getFilePath:[NSString stringWithFormat:@"archives/%@.tar", version]];
    NSString* directoryPath = [self getFilePath:@"versions"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:payloadUrl];
    [request setHTTPMethod:@"GET"];
    AFHTTPRequestOperation* requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    requestOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:tarFilePath append:NO];
    [requestOperation setCompletionBlock:^{
        NSLog(@"Version download completed %@", tarFilePath);
        NSError *error;
        [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:directoryPath withTarPath:tarFilePath error:&error];
        if (error) {
            NSLog(@"Error untarring version %@", error);
        } else {
            NSLog(@"Success downloading and untarring version %@", version);
        }
    }];
    [requestOperation start];
}

-(NSURL *)getUrl:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://marcus.local:4000/%@", path]];
}



@end

@implementation BlowTorchInterceptionCache

- (NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest *)request {
    BOOL isDev = YES;
    if (isDev) { return [super cachedResponseForRequest:request]; }

    NSRange match = [[[request URL] path] rangeOfString:@"/bootstrap-ios"];
    if (match.location == NSNotFound) { return [super cachedResponseForRequest:request]; }

    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"app.js" ofType:@"ios-build"];
    NSData* jsData = [NSData dataWithContentsOfFile:filePath];

    NSURLResponse* response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:@"application/javascript" expectedContentLength:[jsData length] textEncodingName:nil];
    NSCachedURLResponse* cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:jsData];
    return cachedResponse;
}

@end
