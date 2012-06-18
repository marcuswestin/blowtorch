#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "BTIndex.h"

#ifdef DEBUG
static BOOL DEV_MODE = true;
@interface WebView
+ (void)_enableRemoteInspector;
@end

#import "DebugUIWebView.h"

#else 
static BOOL DEV_MODE = false;
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

- (NSString*) getCurrentVersion;
- (NSString*) getCurrentVersionPath:(NSString*)resourcePath;

- (void) createWindowAndWebView;

- (void) registerForPush;

- (void) showLoadingOverlay;
- (void) hideLoadingOverlay;
@end

@implementation BTAppDelegate

@synthesize window, webView, javascriptBridge, serverHost, state, net, overlay, config, isDevMode;

/* App lifecycle
 **********************/
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    state = [[BTState alloc] init];
    net = [[BTNet alloc] init];
    
    config = [NSMutableDictionary dictionary];
    BTInterceptionCache* interceptionCache = [[BTInterceptionCache alloc] init];
    interceptionCache.blowtorchInstance = self;
    [NSURLCache setSharedURLCache:interceptionCache];
    [self createWindowAndWebView];
    [self showLoadingOverlay];
    
#ifdef DEBUG
    [NSClassFromString(@"WebView") _enableRemoteInspector];
#endif
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:@"UIDeviceOrientationDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];


    return YES;
}

-(void)startApp:(BOOL)devMode {
    self.isDevMode = DEV_MODE = devMode;
    [self setClientState:@"installed_version" value:[self getClientState:@"downloaded_version"]];

    NSURL* url = [self getUrl:@"app.html"];
    [self.javascriptBridge resetQueue];
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
    
    NSDictionary* appInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                               config, @"config",
                               [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], @"bundleVersion",
                               nil];
    [self notify:@"app.start" info:appInfo];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self notify:@"app.willResignActive"];
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self notify:@"app.didEnterBackground"];
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [self notify:@"app.willEnterForeground"];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self notify:@"app.didBecomeActive"];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [self notify:@"app.willTerminate"];
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}


/* Native events notifications
 *****************************/

-(void) didRotate:(NSNotification*)notification {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    NSInteger deg = 0;
    if (orientation == UIDeviceOrientationPortraitUpsideDown) {
        deg = 180;
    } else if (orientation == UIDeviceOrientationLandscapeLeft) {
        deg = 90;
    } else if (orientation == UIDeviceOrientationLandscapeRight) {
        deg = -90;
    }
    NSNumber* degNum = [NSNumber numberWithInt:deg];
    [self notify:@"device.rotated" info:[NSDictionary dictionaryWithObject:degNum forKey:@"deg"]];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self notify:@"keyboard.willShow" info:[self keyboardEventInfo:notification]];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self notify:@"keyboard.willHide" info:[self keyboardEventInfo:notification]];
}

- (NSDictionary *)keyboardEventInfo:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSValue *keyboardAnimationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval keyboardAnimationDurationInterval;
    [keyboardAnimationDurationValue getValue:&keyboardAnimationDurationInterval];
    NSNumber* keyboardAnimationDuration = [NSNumber numberWithDouble:keyboardAnimationDurationInterval];
    return [NSDictionary dictionaryWithObject:keyboardAnimationDuration forKey:@"keyboardAnimationDuration"];
}

/* WebView <-> Native API
 ************************/
- (void)javascriptBridge:(WebViewJavascriptBridge *)bridge receivedMessage:(NSString *)messageString fromWebView:(UIWebView *)fromWebView {
    NSDictionary* message = [messageString objectFromJSONString];
    NSDictionary* data = [message objectForKey:@"data"];

    if (!data) { data = [NSDictionary dictionary]; }
    
    __block NSString *responseId = [message objectForKey:@"responseId"];
    __block NSString *command = [message objectForKey:@"command"];
    
    NSLog(@"command %@", command);
    
    ResponseCallback responseCallback = ^(NSString *errorMessage, NSDictionary *response) {
        NSLog(@"respond %@ %@", command, errorMessage);
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
        [self startApp:isDevMode];

    } else if ([command isEqualToString:@"app.show"]) {
        [self hideLoadingOverlay];
        
    } else if ([command isEqualToString:@"app.setIconBadgeNumber"]) {
        NSNumber* number = [data objectForKey:@"number"];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[number intValue]];
    
    } else if ([command isEqualToString:@"app.getIconBadgeNumber"]) {
        NSNumber* number = [NSNumber numberWithInt:[[UIApplication sharedApplication] applicationIconBadgeNumber]];
        responseCallback(nil, [NSDictionary dictionaryWithObject:number forKey:@"number"]);
        
    } else if ([command isEqualToString:@"console.log"]) {
        NSLog(@"console.log %@", data);

    } else if ([command isEqualToString:@"state.load"]) {
        responseCallback(nil, [state load]);
    
    } else if ([command isEqualToString:@"state.set"]) {
        [state set:[data objectForKey:@"key"] value:[data objectForKey:@"value"]];
        responseCallback(nil, nil);
    
    } else if ([command isEqualToString:@"state.clear"]) {
        [state reset];
    
    } else if ([command isEqualToString:@"push.register"]) {
        [self registerForPush];
        
    } else if ([command isEqualToString:@"media.pick"]) {
        [self pickMedia:responseCallback];
        
    } else if ([command isEqualToString:@"net.cache"]) {
        [self.net cache:[data objectForKey:@"url"] override:!![data objectForKey:@"override"]
                  asUrl:[data objectForKey:@"asUrl"] responseCallback:responseCallback];
    
    } else if ([command isEqualToString:@"device.vibrate"]) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        
    } else if ([command isEqualToString:@"index.build"]) {
        [BTIndex buildIndex:[data objectForKey:@"name"] payloadToStrings:[data objectForKey:@"payloadToStrings"]];
    
    } else if ([command isEqualToString:@"index.lookup"]) {
        BTIndex* index = [BTIndex indexByName:[data objectForKey:@"name"]];
        [index lookup:[data objectForKey:@"searchString"] responseCallback:responseCallback];
        
    } else {
        [self handleCommand:command data:data responseCallback:responseCallback];
    }
}

- (void) handleCommand:(NSString *)command data:(NSDictionary *)data responseCallback:(ResponseCallback)responseCallback {
    [NSException raise:@"BlowTorch abstract method" format:@" handleCommand:data:responseCallback must be overridden"];
}

- (void)notify:(NSString *)event { [self notify:event info:NULL]; }
- (void)notify:(NSString *)event info:(NSDictionary *)info {
    NSLog(@"Notify %@ %@", event, info);
    if (!info) { info = [NSDictionary dictionary]; }
    NSDictionary* message = [NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil];
    [javascriptBridge sendMessage:[message JSONString] toWebView:webView];
}

/* Net API
 *********/
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request url:(NSURL *)url host:(NSString *)host path:(NSString *)path {
    if (!DEV_MODE) {
        // Check currently downloaded version first
        NSString* currentVersionPath = [self getCurrentVersionPath:path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:currentVersionPath]) {
            return [self localFileResponse:currentVersionPath forUrl:url];
        } else {
            // Else check bootstrap files
            if ([path isEqualToString:@"/app.html"] ||
                [path isEqualToString:@"/appJs.html"] ||
                [path isEqualToString:@"/appCss.css"]) {
                
                NSString* bootstrapPath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
                return [self localFileResponse:bootstrapPath forUrl:url];
            }
        }
    }

    if ([[url host] isEqualToString:@"blowtorch"]) {
        NSArray* parts = [[[url path] substringFromIndex:1] componentsSeparatedByString:@"."];
        NSString* type = [parts objectAtIndex:1];
        NSString* path = [parts objectAtIndex:0];
        NSString* path2x = [path stringByAppendingString:@"@2x"];
        if ([self isRetina] && [[NSBundle mainBundle] pathForResource:path2x ofType:type]) {
            path = path2x;
        }
        return [self localFileResponse:[[NSBundle mainBundle] pathForResource:path ofType:type] forUrl:url];
    }
    
    if ([[url host] isEqualToString:@"blowtorchmediapng"]) {
        NSString* mediaId = [[url path] lastPathComponent];
        NSLog(@"Media request %@", mediaId);
        UIImage* image = [mediaCache objectForKey:mediaId];
        NSData* data = UIImagePNGRepresentation(image);
        NSURLResponse* response = [[NSURLResponse alloc] initWithURL:url MIMEType:@"image/png" expectedContentLength:[data length] textEncodingName:nil];
        return [[NSCachedURLResponse alloc] initWithResponse:response data:data];
    }
    
    NSString* cachePath = [BTNet pathForUrl:[url absoluteString]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        return [self localFileResponse:cachePath forUrl:url];
    }
    
    return nil;
}

- (NSCachedURLResponse *)localFileResponse:(NSString *)filePath forUrl:(NSURL*)url {
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    NSString* mimeType = @"";
    if ([[url pathExtension] isEqualToString:@"png"]) {
        mimeType = @"image/png";
    }
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL:url MIMEType:mimeType expectedContentLength:[data length] textEncodingName:nil];
    return [[NSCachedURLResponse alloc] initWithResponse:response data:data];
}


/* Upgrade API
 *************/
- (void)requestUpgrade {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self getUrl:@"upgrade"]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self getUpgradeRequestBody]];
//    [[AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary* upgradeResponse) {
//        NSLog(@"upgrade response %@", upgradeResponse);
//        NSDictionary* commands = [upgradeResponse objectForKey:@"commands"];
//        for (NSString* command in commands) {
//            id value = [commands valueForKey:command];
//            if ([command isEqualToString:@"set_client_id"]) {
//                [self setClientState:@"client_id" value:(NSString*)value];
//            } else if ([command isEqualToString:@"download_version"]) {
//                [self startVersionDownload:(NSString*)value];
//            } else {
//                NSLog(@"Warning: Received unknown command from server %@:%@", command, value);
//            }
//        }
//    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
//        NSLog(@"Warning: upgrade request failed %@", error);
//    }] start];
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
    NSLog(@"Push registration failure %@", err);
    [self notify:@"push.registerFailed" info:nil];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self notify:@"push.notification" info:[NSDictionary dictionaryWithObject:userInfo forKey:@"data"]];
}

/* Misc API
 **********/

static int uniqueId = 1;
- (NSString *)unique {
    int thisId = ++uniqueId;
    return [NSString stringWithFormat:@"%d", thisId];
}

- (BOOL)isRetina {
    return ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0);
}

@synthesize mediaResponseCallback, mediaCache;
- (void)pickMedia:(ResponseCallback)responseCallback {
    if (!mediaCache) { mediaCache = [NSMutableDictionary dictionary]; }
    
    UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
    mediaUI.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    
    // Displays saved pictures and movies, if both are available, from the
    // Camera Roll album.
    mediaUI.mediaTypes = 
    [UIImagePickerController availableMediaTypesForSourceType:
     UIImagePickerControllerSourceTypeSavedPhotosAlbum];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    mediaUI.allowsEditing = NO;
    
    mediaUI.delegate = self;
    
    mediaResponseCallback = responseCallback;
    [self.window.rootViewController presentModalViewController: mediaUI animated: YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    [self.window.rootViewController dismissModalViewControllerAnimated: YES];
    NSString* mediaId = [self unique];
    [mediaCache setObject:image forKey:mediaId];
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                            mediaId, @"mediaId",
                            [NSNumber numberWithFloat:image.size.width], @"width",
                            [NSNumber numberWithFloat:image.size.height], @"height",
                            nil];
    mediaResponseCallback(nil, info);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    NSLog(@"DidCancel");
    [self.window.rootViewController dismissModalViewControllerAnimated: YES];
    NSLog(@"before response");
    mediaResponseCallback(nil, [NSDictionary dictionary]);
    NSLog(@"after response");
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
//    NSDictionary* requestObj = [NSDictionary dictionaryWithObject:[self getClientState] forKey:@"client_state"];
//    NSError *error = nil;
//    NSData *JSONData = AFJSONEncode(requestObj, &error);
//    return error ? nil : JSONData;
    return nil;
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
//    [self setClientState:@"downloading_version" value:version];
//    [[NSFileManager defaultManager] createDirectoryAtPath:[self getFilePath:@"archives"] withIntermediateDirectories:YES attributes:nil error:nil];
//    NSURL* payloadUrl = [self getUrl:[NSString stringWithFormat:@"builds/%@", version]];
//    NSString* tarFilePath = [self getFilePath:[NSString stringWithFormat:@"archives/%@.tar", version]];
//    NSString* directoryPath = [self getFilePath:@"versions"];
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:payloadUrl];
//    [request setHTTPMethod:@"GET"];
//    AFHTTPRequestOperation* requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
//    requestOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:tarFilePath append:NO];
//    [requestOperation setCompletionBlock:^{
//        NSLog(@"Version download completed %@", tarFilePath);
//        NSError *error;
//        [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:directoryPath withTarPath:tarFilePath error:&error];
//        if (error) {
//            NSLog(@"Error untarring version %@", error);
//        } else {
//            [self setClientState:@"downloaded_version" value:version];
//            NSLog(@"Success downloading and untarring version %@", version);
//        }
//    }];
//    [requestOperation start];
}

-(NSURL *)getUrl:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverHost, path]];
}

- (void)createWindowAndWebView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame:screenBounds];
    window.backgroundColor = [UIColor whiteColor];
    [window makeKeyAndVisible];
    window.rootViewController = [[BTViewController alloc] init];

    screenBounds.size.height -= 20;
#ifdef DEBUG
    webView = [[DebugUIWebView alloc] initWithFrame:screenBounds];
#else
    webView = [[UIWebView alloc] initWithFrame:screenBounds];
#endif
    [window.rootViewController.view addSubview:webView];
    javascriptBridge = [WebViewJavascriptBridge javascriptBridgeWithDelegate:self];
    webView.delegate = javascriptBridge;
}

- (void)showLoadingOverlay {
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.y -= 20;
    UIImageView* splashScreen = [[UIImageView alloc] initWithFrame:frame];
    splashScreen.image = [UIImage imageNamed:@"Default"];
    self.overlay = splashScreen;
    [window.rootViewController.view addSubview:splashScreen];
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
    return [self.blowtorchInstance cachedResponseForRequest:(NSURLRequest *)request url:url host:host path:path];
}
@end
