#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "UIColor+Util.h"
#import "NSString+HHUriEncoding.h"

#ifdef DEBUG
#import "DebugUIWebView.h"
#endif

static BTAppDelegate* instance;

@implementation BTAppDelegate {
    NSString* _serverScheme;
    NSString* _serverHost;
    NSString* _serverPort;
    UILabel* _reloadView;
    BTCallback _menuCallback;
    NSDictionary* _launchNotification;
    UIView* _splashScreen;

}

@synthesize window, webView, javascriptBridge=_bridge, config;

+ (BTAppDelegate *)instance { return instance; }

/* App lifecycle
 **********************/
- (void)setupModules {}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    instance = self;
    config = [NSMutableDictionary dictionary];
    
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];

    [self createWindowAndWebView];
    [self showSplashScreen:@{} callback:NULL];
    
#if defined(DEBUG) && defined(__IPHONE_5_0) && !defined(__IPHONE_7_0)
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

-(void)setupApp {
#ifdef DEBUG
    [self _renderDevTools];
#endif
    
    [self setupHandlers];
    [self setupModules];
    [self startApp];
}

-(void)_renderDevTools {
    _reloadView = [[UILabel alloc] initWithFrame:CGRectMake(320-45,60,40,40)];
    _reloadView.userInteractionEnabled = YES;
    _reloadView.text = @"R";
    _reloadView.font = [UIFont fontWithName:@"Open Sans" size:20];
    _reloadView.textAlignment = NSTextAlignmentCenter;
    _reloadView.backgroundColor = [UIColor whiteColor];
    _reloadView.alpha = 0.05;
    [_reloadView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_reloadTap)]];
    [window.rootViewController.view addSubview:_reloadView];
}
-(void)_reloadTap {
    NSLog(@"\n\n\nRELOAD APP\n\n");
    [self reloadApp];
    _reloadView.backgroundColor = [UIColor blueColor];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        _reloadView.backgroundColor = [UIColor whiteColor];
    });
}

-(void)startApp {
    [_bridge reset];
    NSURL* appHtmlUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/resources/app.html", self.serverUrl]];
    [webView loadRequest:[NSURLRequest requestWithURL:appHtmlUrl]];
    NSString* bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString* client = [@"ios-" stringByAppendingString:bundleVersion];
    [self notify:@"app.init" info:@{ @"config":config, @"client":client }];
    
    [self putWindowUnderKeyboard];
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
    [self notify:@"keyboard.willShow" info:[self _keyboardEventInfo:notification]];
}
- (void)keyboardWillHide:(NSNotification *)notification {
    [self notify:@"keyboard.willHide" info:[self _keyboardEventInfo:notification]];
}
- (void)keyboardDidHide:(NSNotification*)notification {
    [self notify:@"keyboard.didHide" info:[self _keyboardEventInfo:notification]];
}
- (NSDictionary *)_keyboardEventInfo:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSValue *keyboardAnimationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval keyboardAnimationDurationInterval;
    [keyboardAnimationDurationValue getValue:&keyboardAnimationDurationInterval];
    NSNumber* keyboardAnimationDuration = [NSNumber numberWithDouble:keyboardAnimationDurationInterval];
    return [NSDictionary dictionaryWithObject:keyboardAnimationDuration forKey:@"keyboardAnimationDuration"];
}


/* WebView <-> Native API
 ************************/
- (void)setupHandlers {
    // app.*
    [self handleCommand:@"app.reload" handler:^(id data, BTCallback responseCallback) {
        [self reloadApp:data];
    }];
    [self handleCommand:@"splashScreen.hide" handler:^(id data, BTCallback  responseCallback) {
        [self hideSplashScreen:data];
        if (_launchNotification) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didLaunchWithNotification" object:nil userInfo:@{ @"launchNotification":_launchNotification }];
            _launchNotification = nil;
        }
    }];
    [self handleCommand:@"splashScreen.show" handler:^(id params, BTCallback callback) {
        [self showSplashScreen:params callback:callback];
    }];
    [self handleCommand:@"app.setIconBadgeNumber" handler:^(id data, BTCallback responseCallback) {
        NSNumber* number = [data objectForKey:@"number"];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[number intValue]];
    }];
    [self handleCommand:@"app.getIconBadgeNumber" handler:^(id data, BTCallback responseCallback) {
        NSNumber* number = [NSNumber numberWithInt:[[UIApplication sharedApplication] applicationIconBadgeNumber]];
        responseCallback(nil, [NSDictionary dictionaryWithObject:number forKey:@"number"]);
    }];
    
    // device.*
    [self handleCommand:@"device.vibrate" handler:^(id data, BTCallback responseCallback) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }];
    
    // viewport.*
    [self handleCommand:@"viewport.expand" handler:^(id data, BTCallback responseCallback) {
        float addHeight = [data[@"height"] floatValue];
        float normalHeight = [[UIScreen mainScreen] bounds].size.height;
        CGRect frame = webView.frame;
        webView.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, normalHeight + addHeight);
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
    
    [self handleCommand:@"BT.setStatusBar" handler:^(id data, BTCallback callback) {
        [self setStatusBar:data callback:callback];
    }];
}

- (void)reloadApp { [self reloadApp:nil]; }
- (void)reloadApp:(NSDictionary*)data {
    [self setStatusBar:@{ @"visible":[NSNumber numberWithBool:NO], @"animation":@"slide" } callback:^(id err, id responseData) {}];
    [self showSplashScreen:@{ @"fade":[NSNumber numberWithDouble:0.25] } callback:^(id err, id responseData) {
        [self startApp];
    }];
}

- (void)setStatusBar:(NSDictionary*)data callback:(BTCallback)callback {
    UIStatusBarAnimation animation = UIStatusBarAnimationNone;
    if ([data[@"animation"] isEqualToString:@"fade"]) { animation = UIStatusBarAnimationFade; }
    if ([data[@"animation"] isEqualToString:@"slide"]) { animation = UIStatusBarAnimationSlide; }
    BOOL hidden = ![data[@"visible"] boolValue];
    [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animation];
    callback(nil,nil);
}

+ (void)notify:(NSString *)name info:(NSDictionary *)info { [instance notify:name info:info]; }
+ (void)notify:(NSString *)name { [instance notify:name]; }
- (void)notify:(NSString *)event { [self notify:event info:NULL]; }
- (void)notify:(NSString *)event info:(id)info {
//    NSLog(@"Notify %@ %@", event, info);
    if (!info) { info = [NSDictionary dictionary]; }
    
    if ([info isKindOfClass:[NSError class]]) {
        info = [NSDictionary dictionaryWithObjectsAndKeys:[info localizedDescription], @"message", nil];
    }
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:event object:nil userInfo:info]];
    [_bridge send:[NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil]];
}

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
- (void)putWindowOverKeyboard {
    // cause the keyboard (and its webview accessory - "prev/next/done" toolbar - to render underneath the webview)
    window.windowLevel = UIWindowLevelStatusBar - 0.1;
}
- (void)putWindowUnderKeyboard {
    window.windowLevel = UIWindowLevelNormal;
}

- (void)handleCommand:(NSString *)handlerName handler:(BTCommandHandler)handler {
    [self.javascriptBridge registerHandler:handlerName handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"Handle command %@", handlerName);
        NSString* async = data ? data[@"async"] : nil;
        if (async) {
            dispatch_queue_t queue;
            if ([async isEqualToString:@"main"]) {
                queue = dispatch_get_main_queue();
            } else if ([async isEqualToString:@"high"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
            } else if ([async isEqualToString:@"low"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            } else if ([async isEqualToString:@"background"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
            } else {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            }
            dispatch_async(queue, ^{
                [self _doHandleCommand:handlerName handler:handler data:data responseCallback:responseCallback];
            });
        } else {
            [self _doHandleCommand:handlerName handler:handler data:data responseCallback:responseCallback];
        }
    }];
}

- (void)_doHandleCommand:(NSString*)handlerName handler:(BTCommandHandler)handler data:(NSDictionary*)data responseCallback:(WVJBResponseCallback)responseCallback {
    @try {
        handler(data, ^(id err, id responseData) {
            NSLog(@"Respond command %@", handlerName);
            if (err) {
                if ([err isKindOfClass:[NSError class]]) {
                    err = @{ @"message":[err localizedDescription] };
                }
                responseCallback(@{ @"error":err });
            } else if (responseData) {
                responseCallback(@{ @"responseData":responseData });
            } else {
                responseCallback(@{});
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"WARNING: handleCommand:%@ threw with params:%@ error:%@", handlerName, data, exception);
        responseCallback(@{ @"error": @{ @"message":exception.name, @"reason":exception.reason }});
    }
}

- (void)handleRequests:(NSString *)command handler:(BTRequestHandler)requestHandler {
    [WebViewProxy handleRequestsWithHost:self.serverHost path:command handler:^(NSURLRequest *req, WVPResponse *res) {
        NSDictionary* params = [req.URL.query parseQueryParams];
        requestHandler(params, res);
    }];
}

- (void)_respond:(WVPResponse*)res fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
    NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    [res respondWithData:data mimeType:mimeType];
}

- (void)createWindowAndWebView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame:screenBounds];
    [window makeKeyAndVisible];
    window.rootViewController = [[BTViewController alloc] init];

#ifdef DEBUG
    webView = [[DebugUIWebView alloc] initWithFrame:screenBounds];
#else
    webView = [[UIWebView alloc] initWithFrame:screenBounds];
#endif
    webView.suppressesIncrementalRendering = YES;
    webView.keyboardDisplayRequiresUserAction = NO;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    webView.clipsToBounds = YES;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    webView.scrollView.bounces = NO;
    webView.scrollView.scrollsToTop = NO;
    webView.scrollView.clipsToBounds = YES;
    webView.scrollView.scrollEnabled = NO;
//    webView.opaque = NO;
//    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = YES;
    webView.backgroundColor = window.backgroundColor;
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

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    }
    return YES;
}

- (void)showSplashScreen:(NSDictionary*)params callback:(BTCallback)callback {
    if (!callback) { callback = ^(id err, id responseData) {}; }
    if (_splashScreen) { return callback(nil,nil); }
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    UIImageView* splashScreen = [[UIImageView alloc] initWithFrame:screenBounds];
    _splashScreen = splashScreen;
    
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if (screenSize.height > 480.0f) {
            splashScreen.image = [UIImage imageNamed:@"Default-568h"];
        } else {
            splashScreen.image = [UIImage imageNamed:@"Default"];
        }
    } else {
        // TODO iPad
        splashScreen.image = [UIImage imageNamed:@"Default"];
    }
    
    NSNumber* fade = params[@"fade"];
    if (fade) {
        splashScreen.alpha = 0.0;
        [window.rootViewController.view addSubview:splashScreen];
        [UIView animateWithDuration:[fade doubleValue] animations:^{
            splashScreen.alpha = 1.0;
        } completion:^(BOOL finished) {
            callback(nil,nil);
        }];
    } else {
        [window.rootViewController.view addSubview:splashScreen];
        callback(nil,nil);
    }
}

- (void)hideSplashScreen:(NSDictionary *)data {
    if (!_splashScreen) { return; }
    UIView* hideOverlay = _splashScreen;
    _splashScreen = nil;
    NSNumber* fade = [data objectForKey:@"fade"];
    if (!fade) {
        return [hideOverlay removeFromSuperview];
    }
    [UIView animateWithDuration:[fade doubleValue] animations:^{
        hideOverlay.alpha = 0;
    } completion:^(BOOL finished) {
        [hideOverlay removeFromSuperview];
    }];
}
@end
