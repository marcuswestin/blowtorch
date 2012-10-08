#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "BTIndex.h"
#import "BTTextInput.h"

#ifdef DEBUG
static BOOL DEV_MODE = true;

#import "DebugUIWebView.h"

#else 
static BOOL DEV_MODE = false;
#endif

@interface BTAppDelegate (hidden)
- (NSURL*) getUrl:(NSString*) path;
- (NSString*) getFilePath:(NSString*) name;

- (NSString*) getCurrentVersionPath:(NSString*)resourcePath;

- (void) createWindowAndWebView;

- (void) showLoadingOverlay;
- (void) hideLoadingOverlay;
@end

@implementation BTAppDelegate

@synthesize window, webView, javascriptBridge=_bridge, serverHost, state, net, overlay, config, launchNotification;

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
    [NSClassFromString(@"WebView") performSelector:@selector(_enableRemoteInspector)];
#endif
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    NSNotificationCenter* notifications = [NSNotificationCenter defaultCenter];
    
    [notifications addObserver:self selector:@selector(didRotate:) name:@"UIDeviceOrientationDidChangeNotification" object:nil];
    [notifications addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [notifications addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [notifications addObserver:self selector:@selector(handleBTNotification:) name:@"bt.notify" object:nil];
    
    launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    
    return YES;
}

-(void)startApp:(BOOL)devMode {
    DEV_MODE = devMode;
    NSString* downloadedVersion = [self getAppInfo:@"downloadedVersion"];
    if (downloadedVersion) {
        [self setAppInfo:@"installedVersion" value:downloadedVersion];
    }
    
    NSURL* url = [self getUrl:@"app"];
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
    
    NSString* bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString* client = [bundleVersion stringByAppendingString:@"-ios"];
    NSDictionary* appInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                               config, @"config",
                               client, @"client",
                               nil];
    [self notify:@"app.start" info:appInfo];
}

- (void)setAppInfo:(NSString *)key value:(NSString *)value {
    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary:[state load:@"__btAppInfo"]];
    [info setObject:value forKey:key];
    [state set:@"__btAppInfo" value:info];
}

- (NSString *)getAppInfo:(NSString *)key {
    NSDictionary* info = [state load:@"__btAppInfo"];
    if (!info) { return nil; }
    return [info objectForKey:key];
}

@synthesize pushRegistrationResponse=_pushRegistrationResponse;
- (void)registerForPush:(WVJBResponse*)response {
    _pushRegistrationResponse = response;
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
     (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
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

- (void)handleBTNotification:(NSNotification*)notification {
    [self notify:notification.object info:notification.userInfo];
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
- (void)handleBridgeData:(id)data response:(WVJBResponse *)response {
    NSLog(@"Received unknown message %@", data);
}

- (void)setupBridgeHandlers {
//    ResponseCallback responseCallback = ^(NSString *errorMessage, NSDictionary *response) {
//        NSLog(@"respond %@ %@", command, errorMessage);
//        NSMutableDictionary* responseMessage = [NSMutableDictionary dictionary];
//        
//        if (responseId) {
//            [responseMessage setObject:responseId forKey:@"responseId"];
//        }
//        
//        if (errorMessage) {
//            [responseMessage setObject:errorMessage forKey:@"error"];
//        } else if (response) {
//            [responseMessage setObject:response forKey:@"data"];
//        }
//        
//        [javascriptBridge sendMessage:[responseMessage JSONString] toWebView:fromWebView];
//    };
    
    // app.*
    [_bridge registerHandler:@"app.restart" handler:^(id data, WVJBResponse* response) {
        [self startApp:DEV_MODE];
    }];
    [_bridge registerHandler:@"app.show" handler:^(id data,  WVJBResponse* response) {
        [self hideLoadingOverlay];
        if (launchNotification) {
            [self handlePushNotification:launchNotification didBringAppToForeground:YES];
            launchNotification = nil;
        }
        NSLog(@"APP HAS SHOWN");
    }];
    [_bridge registerHandler:@"app.setIconBadgeNumber" handler:^(id data, WVJBResponse* response) {
        NSNumber* number = [data objectForKey:@"number"];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[number intValue]];
    }];
    [_bridge registerHandler:@"app.getIconBadgeNumber" handler:^(id data, WVJBResponse* response) {
        NSNumber* number = [NSNumber numberWithInt:[[UIApplication sharedApplication] applicationIconBadgeNumber]];
        [response respondWith:[NSDictionary dictionaryWithObject:number forKey:@"number"]];
    }];
    
    // console.*
    [_bridge registerHandler:@"console.log" handler:^(id data, WVJBResponse* response) {
        
    }];
    
    // state.*
    [_bridge registerHandler:@"state.load" handler:^(id data, WVJBResponse* response) {
        [response respondWith:[state load:[data objectForKey:@"key"]]];
    }];
    [_bridge registerHandler:@"state.set" handler:^(id data, WVJBResponse* response) {
        [state set:[data objectForKey:@"key"] value:[data objectForKey:@"value"]];
        [response respondWith:nil];
    }];
    [_bridge registerHandler:@"state.clear" handler:^(id data, WVJBResponse* response) {
        [state reset];
        [response respondWith:nil];
    }];
    
    // push.*
    [_bridge registerHandler:@"push.register" handler:^(id data, WVJBResponse* response) {
        [self registerForPush:response];
    }];
    
    // media.*
    [_bridge registerHandler:@"media.pick" handler:^(id data, WVJBResponse* response) {
        [self pickMedia:data response:response];
    }];
    
    // menu.*
    [_bridge registerHandler:@"menu.show" handler:^(id data, WVJBResponse* response) {
        [self showMenu:data response:response];
    }];
    
    // device.*
    [_bridge registerHandler:@"device.vibrate" handler:^(id data, WVJBResponse* response) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }];
    
    // version.*
    [_bridge registerHandler:@"version.download" handler:^(id data, WVJBResponse* response) {
        [self downloadAppVersion:data response:response];
    }];
    
    // testInput.*
    [_bridge registerHandler:@"textInput.show" handler:^(id data, WVJBResponse* response) {
        [BTTextInput show:data webView:webView];
    }];
    [_bridge registerHandler:@"textInput.hide" handler:^(id data, WVJBResponse* response) {
        [BTTextInput hide];
    }];
    [_bridge registerHandler:@"textInput.animate" handler:^(id data, WVJBResponse* response) {
        [BTTextInput animate:data];
    }];
    [_bridge registerHandler:@"textInput.set" handler:^(id data, WVJBResponse* response) {
        [BTTextInput set:data];
    }];
    
//    // index.*
//    [_bridge registerHandler:@"index.build" handler:^(id data, WVJBResponseCallback responseCallback) {
//        [BTIndex buildIndex:[data objectForKey:@"name"] payloadToStrings:[data objectForKey:@"payloadToStrings"]];
//    }];
//    [_bridge registerHandler:@"index.lookup" handler:^(id data, WVJBResponseCallback responseCallback) {
//        BTIndex* index = [BTIndex indexByName:[data objectForKey:@"name"]];
//        [index lookup:[data objectForKey:@"searchString"] responseCallback:responseCallback];
//    }];
}

- (void)notify:(NSString *)event { [self notify:event info:NULL]; }
- (void)notify:(NSString *)event info:(NSDictionary *)info {
    if (![event isEqualToString:@"device.rotated"]) {
        NSLog(@"Notify %@ %@", event, info);
    }
    if (!info) { info = [NSDictionary dictionary]; }
    NSDictionary* message = [NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil];
    [_bridge send:message];
}

/* Net API
 *********/
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request url:(NSURL *)url host:(NSString *)host path:(NSString *)path {
    // Check currently downloaded version first
    // This hits disc TWICE PER REQUEST. FOR ALL REQUESTS. FIX that.
//    NSString* currentVersionPath = [self getCurrentVersionPath:path];
//    if (false && currentVersionPath && [[NSFileManager defaultManager] fileExistsAtPath:currentVersionPath]) {
//        return [self localFileResponse:currentVersionPath forUrl:url];
//    } else
        if (!DEV_MODE) {
        // Else check bootstrap files
        if ([path isEqualToString:@"/app.html"] ||
            [path isEqualToString:@"/appJs.html"] ||
            [path isEqualToString:@"/appCss.css"]) {
            
            NSString* bootstrapPath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
            return [self localFileResponse:bootstrapPath forUrl:url];
        }
    }
    
    NSString* btPrefix = @"/blowtorch/";
    if ([[url path] hasPrefix:btPrefix]) {
        NSString* path = [[url path] substringFromIndex:btPrefix.length];
        NSArray* parts = [path componentsSeparatedByString:@"/"];
        if ([[parts objectAtIndex:0] isEqualToString:@"media"]) {
            NSString* format = [[url path] pathExtension];
            NSString* mediaId = [parts.lastObject stringByDeletingPathExtension];
            UIImage* image = [_mediaCache objectForKey:mediaId];
            NSData* data;
            NSString* mimeType;
            if ([format isEqualToString:@"png"]) {
                data = UIImagePNGRepresentation(image);
                mimeType = @"image/png";
            } else if ([format isEqualToString:@"jpg"] || [format isEqualToString:@"jpeg"]) {
                data = UIImageJPEGRepresentation(image, .8);
                mimeType = @"image/jpg";
            } else {
                return nil;
            }
            
            NSURLResponse* response = [[NSURLResponse alloc] initWithURL:url MIMEType:mimeType expectedContentLength:[data length] textEncodingName:nil];
            return [[NSCachedURLResponse alloc] initWithResponse:response data:data];
        }
    }
    
    NSString* staticPrefix = @"/static/";
    if ([[url path] hasPrefix:staticPrefix]) {
        NSString* path = [[url path] substringFromIndex:staticPrefix.length];
        NSArray* parts = [path componentsSeparatedByString:@"/"];

        if ([[parts objectAtIndex:0] isEqualToString:@"img"]) {
            NSArray* file = [path componentsSeparatedByString:@"."];
            NSString* type = [file objectAtIndex:1];
            NSString* path = [file objectAtIndex:0];
            NSString* path2x = [path stringByAppendingString:@"@2x"];
            if ([self isRetina] && [[NSBundle mainBundle] pathForResource:path2x ofType:type]) {
                path = path2x;
            }
            return [self localFileResponse:[[NSBundle mainBundle] pathForResource:path ofType:type] forUrl:url];
        } else if ([[parts objectAtIndex:0] isEqualToString:@"fonts"]) {
            NSString* filePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
            return [self localFileResponse:filePath forUrl:url];
        }
    }
    
    if ([[url path] hasPrefix:@"/local_cache"]) {
        NSString* cachePath = [BTNet pathForUrl:[url absoluteString]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
            NSLog(@"Found file in cache! %@", url);
            return [self localFileResponse:cachePath forUrl:url];
        }
    }
    
    return nil;
}

- (NSCachedURLResponse *)localFileResponse:(NSString *)filePath forUrl:(NSURL*)url {
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    NSString* mimeType = @"";
    NSString* extension = [url pathExtension];
    if ([extension isEqualToString:@"png"]) {
        mimeType = @"image/png";
    } else if ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"]) {
        mimeType = @"image/jpg";
    } else if ([extension isEqualToString:@"woff"]) {
        mimeType = @"font/woff";
    } else if ([extension isEqualToString:@"ttf"]) {
        mimeType = @"font/opentype";
    }
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL:url MIMEType:mimeType expectedContentLength:[data length] textEncodingName:nil];
    return [[NSCachedURLResponse alloc] initWithResponse:response data:data];
}


/* Upgrade API
 *************/
- (void)downloadAppVersion:(NSDictionary *)data response:(WVJBResponse *)response {
    NSString* url = [data objectForKey:@"url"];
    NSDictionary* headers = [data objectForKey:@"headers"];
    NSString* version = [url urlEncodedString];
    NSString* directoryPath = [self getFilePath:[@"versions/" stringByAppendingString:version]];
    [BTNet request:url method:@"GET" headers:headers params:nil responseCallback:^(id error, NSDictionary *netData) {
        if (error) {
            [response respondWithError:error];
            return;
        }
        NSData* tarData = [netData objectForKey:@"responseData"];
        if (!tarData || tarData.length == 0) {
            NSLog(@"Received download response with no data");
            return;
        }
        NSError *tarError;
        [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:directoryPath withTarData:tarData error:&tarError];
        if (tarError) {
            NSLog(@"Error untarring version %@", error);
            [response respondWithError:@"Error untarring version"];
        } else {
            [self setAppInfo:@"downloadedVersion" value:version];
            NSLog(@"Success downloading and untarring version %@", version);
            [response respondWith:nil];
        }
    }];
}

- (NSString *)getCurrentVersion {
    return [self getAppInfo:@"installedVersion"];
}

/* Push API
 **********/
- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString * tokenAsString = [[[deviceToken description]
                                 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] 
                                stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSDictionary* info = [NSDictionary dictionaryWithObject:tokenAsString forKey:@"deviceToken"];
    [self notify:@"push.registered" info:info];
    if (_pushRegistrationResponse) {
        [_pushRegistrationResponse respondWith:info];
        _pushRegistrationResponse = nil;
    }
}     

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Push registration failure %@", err);
    [self notify:@"push.registerFailed" info:nil];
    if (_pushRegistrationResponse) {
        [_pushRegistrationResponse respondWithError:@"Notifications were not allowed."];
        _pushRegistrationResponse = nil;
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)notification {
    [self handlePushNotification:notification didBringAppToForeground:(application.applicationState != UIApplicationStateActive)];
}

- (void)handlePushNotification:(NSDictionary *)notification didBringAppToForeground:(BOOL)didBringAppToForeground {
    NSNumber* didBringAppIntoForegroundObj = [NSNumber numberWithBool:(didBringAppToForeground)];
    [self notify:@"push.notification" info:[NSDictionary dictionaryWithObjectsAndKeys:
                                            notification, @"data",
                                            didBringAppIntoForegroundObj, @"didBringAppIntoForeground",
                                            nil]];
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

@synthesize mediaResponse=_mediaResponse, mediaCache=_mediaCache;
- (void)pickMedia:(NSDictionary*)data response:(WVJBResponse *)response {
    if (!_mediaCache) { _mediaCache = [NSMutableDictionary dictionary]; }
    
    UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
    NSString* source = [data objectForKey:@"source"];
    if (!source) {
        source = @"libraryPhotos";
    }
    
    if ([source isEqualToString:@"libraryPhotos"]) {
        mediaUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    } else if ([source isEqualToString:@"librarySavedPhotos"]) {
        mediaUI.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    } else if ([source isEqualToString:@"camera"]) {
        mediaUI.sourceType = UIImagePickerControllerSourceTypeCamera;
    } else {
        return [response respondWithError:@"Unknown source"];
    }
    
    if ([data objectForKey:@"allowsEditing"]) {
        mediaUI.allowsEditing = YES;
    } else {
        mediaUI.allowsEditing = NO;
    }
    
    mediaUI.delegate = self;
    
    _mediaResponse = response;
    [self.window.rootViewController presentModalViewController: mediaUI animated: YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    [self.window.rootViewController dismissModalViewControllerAnimated: YES];
    NSString* mediaId = [self unique];
    [_mediaCache setObject:image forKey:mediaId];
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                            mediaId, @"mediaId",
                            [NSNumber numberWithFloat:image.size.width], @"width",
                            [NSNumber numberWithFloat:image.size.height], @"height",
                            nil];
    [_mediaResponse respondWith:info];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self.window.rootViewController dismissModalViewControllerAnimated: YES];
    [_mediaResponse respondWith:[NSDictionary dictionary]];
}

- (void)showMenu:(NSDictionary *)data response:(WVJBResponse *)response {
    _menuResponse = response;
    UIActionSheet* sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    for (NSString* title in [data objectForKey:@"titles"]) {
        [sheet addButtonWithTitle:title];
    }
    [sheet showInView:self.webView];
}

@synthesize menuResponse=_menuResponse;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    [_menuResponse respondWith:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:buttonIndex] forKey:@"index"]];
}

- (void)actionSheetCancel:(UIActionSheet *)actionSheet {
    [_menuResponse respondWith:nil];
}

@end

/* Private implementations
 *************************/

@implementation BTAppDelegate (hidden)

- (NSString *)getCurrentVersionPath:(NSString *)resourcePath {
    return [self getFilePath:[NSString stringWithFormat:@"versions/%@/%@", [self getCurrentVersion], resourcePath]];
}

- (NSString *)getFilePath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

-(NSURL *)getUrl:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverHost, path]];
}

- (void)createWindowAndWebView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame:screenBounds];
    window.backgroundColor = [UIColor grayColor];
    [window makeKeyAndVisible];
    window.rootViewController = [[BTViewController alloc] init];
    
    screenBounds.size.height -= 20;
#ifdef DEBUG
    webView = [[DebugUIWebView alloc] initWithFrame:screenBounds];
#else
    webView = [[UIWebView alloc] initWithFrame:screenBounds];
#endif
    webView.clipsToBounds = YES;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    [window.rootViewController.view addSubview:webView];
    _bridge = [WebViewJavascriptBridge bridgeForWebView:webView handler:^(id data, WVJBResponse *response) {
        [self handleBridgeData:data response:response];
    }];
    [self setupBridgeHandlers];
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
    [UIView animateWithDuration:0.2 animations:^{
        self.overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [self.overlay removeFromSuperview];
    }];
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
