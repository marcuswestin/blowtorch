#import "BTAppDelegate.h"
#import "AFJSONUtilities.h"
#import "NSFileManager+Tar.h"

@interface BTAppDelegate (hidden)
- (NSData*) getUpgradeRequestBody;

- (NSDictionary*) getClientState;
- (id) getClientState:(NSString*)name;
- (NSDictionary*) setClientState:(NSString*)name value:(id)value;
- (NSString*) getClientStateFilePath;

- (void) startVersionDownload:(NSString*)version;
- (void) loadCurrentVersionApp;
- (NSURL*) getUrl:(NSString*) path;
- (NSString*) getFilePath:(NSString*) name;
- (NSCachedURLResponse*) localFileResponse:(NSString*)filePath forRequest:(NSURLRequest*)request;

- (NSString*) getCurrentVersion;
- (NSString*) getCurrentVersionPath:(NSString*)resourcePath;

- (void) createWindowAndWebView;
@end

@implementation BTAppDelegate

@synthesize window, webView, javascriptBridge;


/* Native app lifecycle
 **********************/
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    BTInterceptionCache* interceptionCache = [[BTInterceptionCache alloc] init];
    interceptionCache.blowtorchInstance = self;
    [NSURLCache setSharedURLCache:interceptionCache];
    [self createWindowAndWebView];
    [self loadCurrentVersionApp];
    [self requestUpgrade];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}


/* WebView <-> Native API
 ************************/
- (void)javascriptBridge:(WebViewJavascriptBridge *)bridge receivedMessage:(NSString *)messageString fromWebView:(UIWebView *)fromWebView {
    NSDictionary* message = [messageString objectFromJSONString];
    NSString *callbackID = [message objectForKey:@"callbackID"];
    NSString *command = [message objectForKey:@"command"];
    NSDictionary *data = [message objectForKey:@"data"];
    
    if ([command isEqualToString:@"blowtorch:reload"]) {
        [self loadCurrentVersionApp];
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
        NSDictionary* commands = [upgradeResponse objectForKey:@"commands"];
        for (NSString* command in commands) {
            id value = [commands valueForKey:command];
            if ([command isEqualToString:@"set_client_id"]) {
                [self setClientState:@"client_id" value:(NSString*)value];
            } else if ([command isEqualToString:@"download_version"]) {
                [self startVersionDownload:(NSString*)value];
            } else {
                NSLog(@"Warning: Received unknown command from server %@:%@", command, value);
            }
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        NSLog(@"Warning: upgrade request failed %@", error);
    }] start];
}

@end

@implementation BTAppDelegate (hidden)

- (void) loadCurrentVersionApp {
    [self setClientState:@"installed_version" value:[self getClientState:@"downloaded_version"]];
    
    // Always https?
    NSURL* url = [NSURL URLWithString:@"http://blowtorch-payload/app.html"];
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (NSData *)getUpgradeRequestBody {
    NSDictionary* requestObj = [NSDictionary dictionaryWithObject:[self getClientState] forKey:@"client_state"];
    NSError *error = nil;
    NSData *JSONData = AFJSONEncode(requestObj, &error);
    return error ? nil : JSONData;
}

- (NSDictionary *)getClientState {
    NSString* filePath = [self getClientStateFilePath];
    NSDictionary* clientState = [NSDictionary dictionaryWithContentsOfFile:filePath];
    if (!clientState) {
        clientState = [NSDictionary dictionary];
    }
    return clientState;
}

- (id)getClientState:(NSString *)name {
    return [[self getClientState] objectForKey:name];
}

- (NSString *)getCurrentVersion {
    return [[self getClientState] objectForKey:@"installed_version"];
}

- (NSString *)getCurrentVersionPath:(NSString *)resourcePath {
    return [self getFilePath:[NSString stringWithFormat:@"versions/%@/%@", [self getCurrentVersion], resourcePath]];
}

-(NSDictionary *)setClientState:(NSString *)name value:(id)value {
    NSString* filePath = [self getClientStateFilePath];
    NSMutableDictionary *currentClientState = [NSMutableDictionary dictionaryWithDictionary:[self getClientState]];
    [currentClientState setValue:value forKey:name];
    [currentClientState writeToFile:filePath atomically:YES];
    return currentClientState;
}

- (NSString *)getClientStateFilePath {
    return [self getFilePath:@"blowtorch-client_state"];
}

- (NSString *)getFilePath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

- (void)startVersionDownload:(NSString *)version {
    NSLog(@"Start download %@", version);
    [self setClientState:@"downloading_version" value:version];
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
            [self setClientState:@"downloaded_version" value:version];
            NSLog(@"Success downloading and untarring version %@", version);
        }
    }];
    [requestOperation start];
}

-(NSURL *)getUrl:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://marcus.local:4000/%@", path]];
}

- (void)createWindowAndWebView {
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
}

- (NSCachedURLResponse *)localFileResponse:(NSString *)filePath forRequest:(NSURLRequest*)request {
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    NSString* mimeType = @""; // TODO Determine mimeType based on file extension
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:mimeType expectedContentLength:[data length] textEncodingName:nil];
    return [[NSCachedURLResponse alloc] initWithResponse:response data:data];
}

@end

@implementation BTInterceptionCache

@synthesize blowtorchInstance;

- (NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest *)request {
    NSURL* url = [request URL];
    NSString* host = [url host];
    NSString* path = [url path];
    
    if ([host isEqualToString:@"blowtorch-bootstrap"]) {
        NSLog(@"TODO: intercept blowtorch-bootstrap %@", path);
    } else if ([host isEqualToString:@"blowtorch-payload"]) {
        NSLog(@"intercept blowtorch-payload %@", path);
        NSString* filePath = [self.blowtorchInstance getCurrentVersionPath:path];
        return [self.blowtorchInstance localFileResponse:filePath forRequest:request];
    } else if ([host isEqualToString:@"blowtorch-command"]) {
        NSString* encodedJson = [url query];
        NSLog(@"TODO: intercept blowtorch-command %@ %@", path, encodedJson);
        // Pass through command to command handler
    }
    
    return nil;
}

@end
