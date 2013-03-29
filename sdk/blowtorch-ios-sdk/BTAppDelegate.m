#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "BTIndex.h"
#import "UIColor+Util.h"

#ifdef DEBUG
#import "DebugUIWebView.h"
#endif

@interface BTAppDelegate (hidden)
- (NSURL*) getUrl:(NSString*) path;
- (void) createWindowAndWebView;
- (void) showLoadingOverlay;
- (void) hideLoadingOverlay:(NSDictionary*)data;
- (void)_respond:(WVPResponse*)res fileName:(NSString *)fileName mimeType:(NSString *)mimeType;
- (NSDictionary*) keyboardEventInfo:(NSNotification*) notification;
@end

static BTAppDelegate* instance;

@implementation BTAppDelegate {
    NSString* _serverScheme;
    NSString* _serverHost;
    NSString* _serverPort;
    UILabel* _reloadView;
    BTCallback _menuCallback;
    NSDictionary* _launchNotification;
}

@synthesize window, webView, javascriptBridge=_bridge, overlay, config;

+ (BTAppDelegate *)instance { return instance; }

/* App lifecycle
 **********************/
- (void)setupModules {}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    instance = self;
    config = [NSMutableDictionary dictionary];
    
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];

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
    [notifications addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    
    _launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    
    return YES;
}

- (void)setServerScheme:(NSString*)scheme host:(NSString *)host port:(NSString *)port {
    _serverScheme = scheme;
    _serverHost = host;
    _serverPort = port;
}

- (NSString *)serverHost {
    return _serverHost;
}

- (NSString*) serverUrl {
    if (_serverPort) { return [_serverScheme stringByAppendingFormat:@"//%@:%@", _serverHost, _serverPort]; }
    else { return [_serverScheme stringByAppendingFormat:@"//%@", _serverHost]; }
}

-(void)setupApp:(BOOL)useLocalBuild {
    if (useLocalBuild) {
        [self handleRequests:@"app" handler:^(NSDictionary *params, WVPResponse *response) {
            [self _respond:response fileName:@"app.html" mimeType:@"text/html"];
        }];
        [self handleRequests:@"appJs.js" handler:^(NSDictionary *params, WVPResponse *response) {
            [self _respond:response fileName:@"appJs.html" mimeType:@"application/javascript"];
        }];
        [self handleRequests:@"appCss.css" handler:^(NSDictionary *params, WVPResponse *response) {
            [self _respond:response fileName:@"appCss.css" mimeType:@"text/css"];
        }];
        [self handleRequests:@"lib/jquery-1.8.1.min.js" handler:^(NSDictionary *params, WVPResponse *response) {
            [self _respond:response fileName:@"jquery-1.8.1.min" mimeType:@"application/javascript"];
        }];
    } else {
        [self _renderDevTools];
    }
    
    [self setupBridgeHandlers:useLocalBuild];
    [self setupNetHandlers:useLocalBuild];
    [self setupModules];
}

- (void)setupNetHandlers:(BOOL)useLocalBuild {}

-(void)_renderDevTools {
    _reloadView = [[UILabel alloc] initWithFrame:CGRectMake(320-100,4,40,40)];
    _reloadView.userInteractionEnabled = YES;
    _reloadView.text = @"R";
    _reloadView.font = [UIFont fontWithName:@"Open Sans" size:20];
    _reloadView.textAlignment = NSTextAlignmentCenter;
    _reloadView.backgroundColor = [UIColor whiteColor];
    _reloadView.alpha = 0.25;
    [_reloadView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_reloadTap)]];
    [window.rootViewController.view addSubview:_reloadView];
}
-(void)_reloadTap {
    NSLog(@"\n\n\nRELOAD APP\n\n\n");
    [self startApp];
    _reloadView.backgroundColor = [UIColor blueColor];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        _reloadView.backgroundColor = [UIColor whiteColor];
    });
}

-(void)startApp {
//    NSString* downloadedVersion = [self getAppInfo:@"downloadedVersion"];
//    if (downloadedVersion) {
//        [self setAppInfo:@"installedVersion" value:downloadedVersion];
//    }
    [_bridge reset];
    [webView loadRequest:[NSURLRequest requestWithURL:[self getUrl:@"app"]]];
    NSString* bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString* client = [bundleVersion stringByAppendingString:@"-ios"];
    NSDictionary* appInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                             config, @"config",
                             client, @"client",
                             nil];
    [self notify:@"app.start" info:appInfo];
}

//- (void)setAppInfo:(NSString *)key value:(NSString *)value {
//    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary:[state load:@"__btAppInfo"]];
//    [info setObject:value forKey:key];
//    [state set:@"__btAppInfo" value:info];
//}

//- (NSString *)getAppInfo:(NSString *)key {
//    NSDictionary* info = [state load:@"__btAppInfo"];
//    if (!info) { return nil; }
//    return [info objectForKey:key];
//}

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

- (void)keyboardDidHide:(NSNotification*)notification {
    [self _expandViewport:0.0]; // always return viewport to 0 expansion when keyboard goes away
}

/* WebView <-> Native API
 ************************/
- (void)setupBridgeHandlers:(BOOL)useLocalBuild {
    // app.*
    [self handleCommand:@"app.restart" handler:^(id data, BTCallback responseCallback) {
        [self startApp];
    }];
    [self handleCommand:@"app.show" handler:^(id data, BTCallback  responseCallback) {
        [self hideLoadingOverlay:data];
        if (_launchNotification) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didLaunchWithNotification" object:nil userInfo:@{ @"launchNotification":_launchNotification }];
            _launchNotification = nil;
        }
    }];
    [self handleCommand:@"app.setIconBadgeNumber" handler:^(id data, BTCallback responseCallback) {
        NSNumber* number = [data objectForKey:@"number"];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[number intValue]];
    }];
    [self handleCommand:@"app.getIconBadgeNumber" handler:^(id data, BTCallback responseCallback) {
        NSNumber* number = [NSNumber numberWithInt:[[UIApplication sharedApplication] applicationIconBadgeNumber]];
        responseCallback(nil, [NSDictionary dictionaryWithObject:number forKey:@"number"]);
    }];
    
    // console.*
    [self handleCommand:@"console.log" handler:^(id data, BTCallback responseCallback) {
        
    }];
    
    // menu.*
    [self handleCommand:@"menu.show" handler:^(id data, BTCallback responseCallback) {
        [self showMenu:data callback:responseCallback];
    }];
    
    // device.*
    [self handleCommand:@"device.vibrate" handler:^(id data, BTCallback responseCallback) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }];
    
    // version.*
//    [self handleCommand:@"version.download" handler:^(id data, BTCallback callback) {
//        [self downloadAppVersion:data callback:callback];
//    }];
    
    // viewport.*
    [self handleCommand:@"viewport.expand" handler:^(id data, BTCallback responseCallback) {
        [self _expandViewport:[[data objectForKey:@"height"] floatValue]];
    }];
    [self handleCommand:@"viewport.putOverKeyboard" handler:^(id data, BTCallback responseCallback) {
        [self putWindowOverKeyboard];
    }];
    [self handleCommand:@"viewport.putUnderKeyboard" handler:^(id data, BTCallback responseCallback) {
        [self putWindowUnderKeyboard];
    }];
    
    
    [self handleCommand:@"BTLocale.getCountryCode" handler:^(id data, BTCallback responseCallback) {
        responseCallback(nil, [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]);
    }];
    
    
    [self handleCommand:@"BT.setStatusBar" handler:^(id data, BTCallback responseCallback) {
        [self _setStatusBar:data responseCallback:responseCallback];
    }];
    
    [self handleCommand:@"BT.readResouce" handler:^(id data, BTCallback responseCallback) {
        NSString *path = [[NSBundle mainBundle] pathForResource:data[@"name"] ofType:data[@"type"]];
        responseCallback(nil, [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]);
    }];
    
//    // index.*
//    [_bridge handleCommand:@"index.build" handler:^(id data, WVJBResponseCallback responseCallback) {
//        [BTIndex buildIndex:[data objectForKey:@"name"] payloadToStrings:[data objectForKey:@"payloadToStrings"]];
//    }];
//    [_bridge handleCommand:@"index.lookup" handler:^(id data, WVJBResponseCallback responseCallback) {
//        BTIndex* index = [BTIndex indexByName:[data objectForKey:@"name"]];
//        [index lookup:[data objectForKey:@"searchString"] responseCallback:responseCallback];
//    }];
}

- (void) _setStatusBar:(NSDictionary*)data responseCallback:(BTCallback)responseCallback {
    UIStatusBarAnimation animation = UIStatusBarAnimationNone;
    if ([data[@"animation"] isEqualToString:@"fade"]) { animation = UIStatusBarAnimationFade; }
    if ([data[@"animation"] isEqualToString:@"slide"]) { animation = UIStatusBarAnimationSlide; }
    [[UIApplication sharedApplication] setStatusBarHidden:![data[@"visible"] boolValue] withAnimation:animation];
}

+ (void)notify:(NSString *)name info:(NSDictionary *)info { [instance notify:name info:info]; }
+ (void)notify:(NSString *)name { [instance notify:name]; }
- (void)notify:(NSString *)event { [self notify:event info:NULL]; }
- (void)notify:(NSString *)event info:(NSDictionary *)info {
    if (![event isEqualToString:@"device.rotated"]) {
        NSLog(@"Notify %@ %@", event, info);
    }
    if (!info) { info = [NSDictionary dictionary]; }
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:event object:nil userInfo:info]];
    [_bridge send:[NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil]];
}

/* Upgrade API
 *************/
//- (void)downloadAppVersion:(NSDictionary *)data callback:(BTCallback)callback {
//    NSString* url = [data objectForKey:@"url"];
//    NSDictionary* headers = [data objectForKey:@"headers"];
//    NSString* version = [url urlEncodedString];
//    NSString* directoryPath = [self getFilePath:[@"versions/" stringByAppendingString:version]];
//    [BTNet request:url method:@"GET" headers:headers params:nil responseCallback:^(id error, NSData *tarData) {
//        if (error) {
//            callback(error,nil);
//            return;
//        }
//        if (!tarData || tarData.length == 0) {
//            NSLog(@"Received download response with no data");
//            return;
//        }
//        NSError *tarError;
//        [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:directoryPath withTarData:tarData error:&tarError];
//        if (tarError) {
//            NSLog(@"Error untarring version %@", error);
//            callback(@"Error untarring version", nil);
//        } else {
//            [self setAppInfo:@"downloadedVersion" value:version];
//            NSLog(@"Success downloading and untarring version %@", version);
//            callback(nil,nil);
//        }
//    }];
//}
//
//- (NSString *)getCurrentVersion {
//    return [self getAppInfo:@"installedVersion"];
//}
//- (NSString *)getFilePath:(NSString *)fileName {
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = [paths objectAtIndex:0];
//    return [documentsDirectory stringByAppendingPathComponent:fileName];
//}

/* Remote notifications
 **********************/
- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didRegisterForRemoteNotifications" object:nil userInfo:@{ @"deviceToken":deviceToken }];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didFailToRegisterForRemoteNotifications" object:nil userInfo:nil];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didReceiveRemoteNotification" object:nil userInfo:@{ @"notification":notification }];
}

/* Misc API
 **********/
- (void)_createStatusBarOverlay {
    // Put a transparent view on top of the status bar in order to intercept touch 
    UIView* statusBarOverlay = [[UIView alloc] initWithFrame:[UIApplication sharedApplication].statusBarFrame];
    statusBarOverlay.backgroundColor = [UIColor clearColor];
    [statusBarOverlay addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStatusBarTapped)]];
    [window addSubview:statusBarOverlay];
}

- (void)putWindowOverKeyboard {
    // cause the keyboard (and its webview accessory - "prev/next/done" toolbar - to render underneath the webview)
    window.windowLevel = UIWindowLevelStatusBar - 0.1;
}

- (void)putWindowUnderKeyboard {
    window.windowLevel = UIWindowLevelNormal;
}

- (void) _expandViewport:(float)addHeight {
    float normalHeight = [[UIScreen mainScreen] bounds].size.height;
    CGRect frame = webView.frame;
    CGRect newFrame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, normalHeight + addHeight);
    webView.frame = newFrame;
}

- (void)showMenu:(NSDictionary *)data callback:(BTCallback)callback {
    NSArray* titles = [data objectForKey:@"titles"];
    NSString* title1 = titles.count > 0 ? [titles objectAtIndex:0] : nil;
    NSString* title2 = titles.count > 1 ? [titles objectAtIndex:1] : nil;
    NSString* title3 = titles.count > 2 ? [titles objectAtIndex:2] : nil;
    NSString* title4 = titles.count > 3 ? [titles objectAtIndex:3] : nil;
    
    _menuCallback = callback;
    UIActionSheet* sheet = [[UIActionSheet alloc] initWithTitle:[data objectForKey:@"title"] delegate:self cancelButtonTitle:[data objectForKey:@"cancelTitle"] destructiveButtonTitle:[data objectForKey:@"destructiveTitle"] otherButtonTitles:title1, title2, title3, title4, nil];
    [sheet showInView:self.webView];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    _menuCallback(nil, @{ @"index":[NSNumber numberWithInt:buttonIndex] });
}

- (void)actionSheetCancel:(UIActionSheet *)actionSheet {
    _menuCallback(nil,nil);
}

- (void)handleCommand:(NSString *)handlerName handler:(BTCommandHandler)handler {
    [self.javascriptBridge registerHandler:handlerName handler:^(id data, WVJBResponseCallback responseCallback) {
        handler(data, ^(id err, id responseData) {
            if (err) {
                if ([err isKindOfClass:[NSError class]]) {
                    err = [NSDictionary dictionaryWithObjectsAndKeys:[err localizedDescription], @"message", nil];
                }
                responseCallback([NSDictionary dictionaryWithObject:err forKey:@"error"]);
            } else if (responseData) {
                responseCallback([NSDictionary dictionaryWithObject:responseData forKey:@"responseData"]);
            } else {
                responseCallback([NSDictionary dictionary]);
            }
        });
    }];
}

- (void)handleRequests:(NSString *)command handler:(BTRequestHandler)requestHandler {
    [WebViewProxy handleRequestsWithHost:self.serverHost path:command handler:^(NSURLRequest *req, WVPResponse *res) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSDictionary* params = [req.URL.query parseQueryParams];
            requestHandler(params, res);
        });
    }];
}

@end

/* Private implementations
 *************************/

@implementation BTAppDelegate (hidden)

- (void)_respond:(WVPResponse*)res fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
    NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    [res respondWithData:data mimeType:mimeType];
}

-(NSURL *)getUrl:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverUrl, path]];
}

- (void)createWindowAndWebView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame:screenBounds];
    window.backgroundColor = [UIColor r:146 g:153 b:163];
    [window makeKeyAndVisible];
    window.rootViewController = [[BTViewController alloc] init];
    
    screenBounds.origin.y -= 20;
#ifdef DEBUG
    webView = [[DebugUIWebView alloc] initWithFrame:screenBounds];
#else
    webView = [[UIWebView alloc] initWithFrame:screenBounds];
#endif
    [webView setSuppressesIncrementalRendering:YES];
    webView.keyboardDisplayRequiresUserAction = NO;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    webView.clipsToBounds = YES;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    webView.scrollView.bounces = NO;
    webView.scrollView.scrollsToTop = NO;
    webView.scrollView.clipsToBounds = YES;
    webView.scrollView.scrollEnabled = NO;
    webView.opaque = NO;
    webView.backgroundColor = [UIColor clearColor];
    [window.rootViewController.view addSubview:webView];
    _bridge = [WebViewJavascriptBridge bridgeForWebView:webView webViewDelegate:self handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"Received unknown message %@", data);
    }];

    // we need to handle viewForZoomingInScrollView to avoid shifting the webview contents
    // when a webview text input gains focus and becomes the first responder.
    webView.scrollView.delegate = self;
}

-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return nil;
}

- (void) onStatusBarTapped {
    [self notify:@"statusBar.wasTapped"];
}

- (void)showLoadingOverlay {
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.y -= 20;
    UIImageView* splashScreen = [[UIImageView alloc] initWithFrame:frame];
    splashScreen.image = [UIImage imageNamed:@"Default"];
    self.overlay = splashScreen;
    [window.rootViewController.view addSubview:splashScreen];
}

- (void)hideLoadingOverlay:(NSDictionary *)data {
    NSNumber* fade = [data objectForKey:@"fade"];
    if (fade) {
        [UIView animateWithDuration:[fade doubleValue] animations:^{
            self.overlay.alpha = 0;
        } completion:^(BOOL finished) {
            [self finishHideOverlay];
        }];
    } else {
        [self finishHideOverlay];
    }
}

- (void) finishHideOverlay {
    [self.overlay removeFromSuperview];
    [self _createStatusBarOverlay];
}

- (NSDictionary *)keyboardEventInfo:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSValue *keyboardAnimationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval keyboardAnimationDurationInterval;
    [keyboardAnimationDurationValue getValue:&keyboardAnimationDurationInterval];
    NSNumber* keyboardAnimationDuration = [NSNumber numberWithDouble:keyboardAnimationDurationInterval];
    return [NSDictionary dictionaryWithObject:keyboardAnimationDuration forKey:@"keyboardAnimationDuration"];
}

@end
