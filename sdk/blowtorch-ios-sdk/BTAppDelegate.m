#import "BTAppDelegate.h"
#import "AFJSONUtilities.h"
#import "NSFileManager+Tar.h"


#ifdef DEBUG
static BOOL BTDEV = true;
@interface WebView
+ (void)_enableRemoteInspector;
@end
#else 
static BOOL BTDEV = false;
#endif

@interface BTAppDelegate (hidden)
- (NSData*) getUpgradeRequestBody;

- (NSDictionary*) getClientState;
- (id) getClientState:(NSString*)name;
- (NSDictionary*) setClientState:(NSString*)name value:(id)value;
- (NSString*) getClientStateFilePath;

- (void) startVersionDownload:(NSString*)version;
- (NSURL*) getUrl:(NSString*) path;
- (NSString*) getFilePath:(NSString*) name;
- (NSCachedURLResponse*) localFileResponse:(NSString*)filePath forRequest:(NSURLRequest*)request;

- (NSString*) getCurrentVersion;
- (NSString*) getCurrentVersionPath:(NSString*)resourcePath;

- (void) createWindowAndWebView;

- (void) registerForPush;

- (void) showLoadingOverlay;
- (void) hideLoadingOverlay;
@end

@implementation BTAppDelegate

@synthesize window, webView, javascriptBridge, serverHost, state, overlay, config;

/* App lifecycle
 **********************/
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    state = [[BTState alloc] init];
    config = [NSMutableDictionary dictionary];
    BTInterceptionCache* interceptionCache = [[BTInterceptionCache alloc] init];
    interceptionCache.blowtorchInstance = self;
    [NSURLCache setSharedURLCache:interceptionCache];
    [self createWindowAndWebView];
    [self showLoadingOverlay];
    
#ifdef DEBUG
    [NSClassFromString(@"WebView") _enableRemoteInspector];
#endif
    
    return YES;
}

- (BOOL)isDev { return BTDEV; }

-(void)startApp {
    [self loadCurrentVersionApp];
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
    NSDictionary *data = [message objectForKey:@"data"];
    __block NSString *responseId = [message objectForKey:@"responseId"];
    __block NSString *command = [message objectForKey:@"command"];
    
    NSLog(@"command %@: %@", command, data);
    
    ResponseCallback responseCallback = ^(NSString *errorMessage, NSDictionary *response) {
        NSLog(@"respond to %@ %@ %@", command, errorMessage, response);
        NSMutableDictionary* responseMessage = [NSMutableDictionary dictionary];
        
        if (responseId) {
            [responseMessage setObject:responseId forKey:@"responseId"];
        }
        
        if (errorMessage) {
            [responseMessage setObject:errorMessage forKey:@"error"];
        } else if (response) {
            [responseMessage setObject:response forKey:@"data"];
        }
        
        [javascriptBridge sendMessage:[responseMessage JSONString] toWebView:fromWebView];
    };
    
    if ([command isEqualToString:@"app.restart"]) {
        [self loadCurrentVersionApp];

    } else if ([command isEqualToString:@"app.show"]) {
        [self hideLoadingOverlay];
        
    } else if ([command isEqualToString:@"console.log"]) {
        NSLog(@"console.log %@", data);

    } else if ([command isEqualToString:@"state.load"]) {
        responseCallback(nil, [state load]);
    
    } else if ([command isEqualToString:@"state.set"]) {
        [state set:[data objectForKey:@"key"] value:[data objectForKey:@"value"]];
        responseCallback(nil, nil);
    
    } else if ([command isEqualToString:@"state.reset"]) {
        [state reset];
    
    } else if ([command isEqualToString:@"push.register"]) {
        [self registerForPush];
    
    } else {
        [self handleCommand:command data:data responseCallback:responseCallback];
    }
}

- (void) handleCommand:(NSString *)command data:(NSDictionary *)data responseCallback:(ResponseCallback)responseCallback {
    [NSException raise:@"BlowTorch abstract method" format:@" handleCommand:data:responseCallback must be overridden"];
}

- (void)sendCommand:(NSString *)command data:(NSDictionary *)data {
}

- (void)notify:(NSString *)event info:(NSDictionary *)info {
    NSLog(@"Notify %@ %@", event, info);

    NSDictionary* message = [NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil];
    [javascriptBridge sendMessage:[message JSONString] toWebView:webView];
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

- (void) loadCurrentVersionApp {
    [self setClientState:@"installed_version" value:[self getClientState:@"downloaded_version"]];
    
    NSURL* url = [self getUrl:@"app.html"];
    
    [self.javascriptBridge resetQueue];
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
    
    [self notify:@"app.start" info:self.config];
}


/* Push API
 **********/
- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString * tokenAsString = [[[deviceToken description]
                                 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] 
                                stringByReplacingOccurrencesOfString:@" " withString:@""];
    [self notify:@"push.registered" info:[NSDictionary dictionaryWithObject:tokenAsString forKey:@"deviceToken"]];
}     

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    [self notify:@"push.registerFailed" info:nil];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self notify:@"push.notification" info:[NSDictionary dictionaryWithObject:userInfo forKey:@"data"]];
}

@end

/* Private implementations
 *************************/

@implementation BTAppDelegate (hidden)

- (void)registerForPush {
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
     (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
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
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverHost, path]];
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

- (void)showLoadingOverlay {
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.y -= 10;
    UIImageView* splashScreen = [[UIImageView alloc] initWithFrame:frame];
    splashScreen.image = [UIImage imageNamed:@"Default"];
    self.overlay = splashScreen;
    [window addSubview:splashScreen];
}

- (void)hideLoadingOverlay {
    [self.overlay removeFromSuperview];
}

@end

@implementation BTInterceptionCache

@synthesize blowtorchInstance;

- (NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest *)request {
    NSURL* url = [request URL];
    NSString* host = [url host];
    NSString* path = [url path];
    
    BOOL interceptApp = !BTDEV;
    
    if ([host isEqualToString:@"blowtorch-bootstrap"]) {
        NSLog(@"TODO: intercept blowtorch-bootstrap %@", path);
    } else if ([host isEqualToString:@"blowtorch-payload"] || (interceptApp && [path isEqualToString:@"/app.html"])) {
        NSLog(@"intercept blowtorch-payload %@", path);
        NSString* filePath = [self.blowtorchInstance getCurrentVersionPath:path];
        if (![NSData dataWithContentsOfFile:filePath]) {
            NSArray* parts = [path pathComponents];
            filePath = [[NSBundle mainBundle] pathForResource:[parts lastObject] ofType:nil]; // [path pathExtension]];
        }
        return [self.blowtorchInstance localFileResponse:filePath forRequest:request];
    } else if ([host isEqualToString:@"blowtorch-command"]) {
        NSString* encodedJson = [url query];
        NSLog(@"TODO: intercept blowtorch-command %@ %@", path, encodedJson);
        // Pass through command to command handler
    }
    
    return nil;
}

@end