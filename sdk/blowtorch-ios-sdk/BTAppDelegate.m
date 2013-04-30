#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "BTIndex.h"
#import "UIColor+Util.h"

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
    if (!useLocalBuild) {
        [self _renderDevTools];
    }
    
    [self setupHandlers:useLocalBuild];
    [self setupModules];
}

-(void)_renderDevTools {
    _reloadView = [[UILabel alloc] initWithFrame:CGRectMake(320-100,4,40,40)];
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
    NSLog(@"\n\n\nRELOAD APP\n\n\n");
    [self startApp];
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
- (void)setupHandlers:(BOOL)useLocalBuild {
    // app.*
    [self handleCommand:@"app.reload" handler:^(id data, BTCallback responseCallback) {
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
        UIStatusBarAnimation animation = UIStatusBarAnimationNone;
        if ([data[@"animation"] isEqualToString:@"fade"]) { animation = UIStatusBarAnimationFade; }
        if ([data[@"animation"] isEqualToString:@"slide"]) { animation = UIStatusBarAnimationSlide; }
        [[UIApplication sharedApplication] setStatusBarHidden:![data[@"visible"] boolValue] withAnimation:animation];
        callback(nil,nil);
    }];
}

+ (void)notify:(NSString *)name info:(NSDictionary *)info { [instance notify:name info:info]; }
+ (void)notify:(NSString *)name { [instance notify:name]; }
- (void)notify:(NSString *)event { [self notify:event info:NULL]; }
- (void)notify:(NSString *)event info:(NSDictionary *)info {
//    NSLog(@"Notify %@ %@", event, info);
    if (!info) { info = [NSDictionary dictionary]; }
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
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSDictionary* params = [req.URL.query parseQueryParams];
            requestHandler(params, res);
        });
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

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    }
    return YES;
}

- (void)showLoadingOverlay {
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.y -= 20;
    UIImageView* splashScreen = [[UIImageView alloc] initWithFrame:frame];
    
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
    self.overlay = splashScreen;
    [window.rootViewController.view addSubview:splashScreen];
}

- (void)hideLoadingOverlay:(NSDictionary *)data {
    if (!self.overlay) { return; }
    UIView* hideOverlay = self.overlay;
    self.overlay = nil;
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
