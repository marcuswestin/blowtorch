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
    BTResponseCallback _menuCallback;
}

@synthesize window, webView, javascriptBridge=_bridge, overlay, config, launchNotification;

+ (BTAppDelegate *)instance { return instance; }

/* App lifecycle
 **********************/
- (void)setupModules {}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    instance = self;
    config = [NSMutableDictionary dictionary];
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
    
    launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    
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
        [WebViewProxy handleRequestsWithHost:self.serverHost path:@"/app" handler:^(NSURLRequest* req, WVPResponse *res) {
            [self _respond:res fileName:@"app.html" mimeType:@"text/html"];
        }];
        [WebViewProxy handleRequestsWithHost:self.serverHost path:@"appJs.js" handler:^(NSURLRequest *req, WVPResponse *res) {
            [self _respond:res fileName:@"appJs.html" mimeType:@"application/javascript"];
        }];
        [WebViewProxy handleRequestsWithHost:self.serverHost path:@"appCss.css" handler:^(NSURLRequest *req, WVPResponse *res) {
            [self _respond:res fileName:@"appCss.css" mimeType:@"text/css"];
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

@synthesize pushRegistrationResponseCallback=_pushRegistrationResponseCallback;
- (void)registerForPush:(BTResponseCallback)responseCallback {
    _pushRegistrationResponseCallback = responseCallback;
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
    [self registerHandler:@"app.restart" handler:^(id data, BTResponseCallback responseCallback) {
        [self startApp];
    }];
    [self registerHandler:@"app.show" handler:^(id data, BTResponseCallback  responseCallback) {
        [self hideLoadingOverlay:data];
        if (launchNotification) {
            [self handlePushNotification:launchNotification didBringAppToForeground:YES];
            launchNotification = nil;
        }
    }];
    [self registerHandler:@"app.setIconBadgeNumber" handler:^(id data, BTResponseCallback responseCallback) {
        NSNumber* number = [data objectForKey:@"number"];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[number intValue]];
    }];
    [self registerHandler:@"app.getIconBadgeNumber" handler:^(id data, BTResponseCallback responseCallback) {
        NSNumber* number = [NSNumber numberWithInt:[[UIApplication sharedApplication] applicationIconBadgeNumber]];
        responseCallback(nil, [NSDictionary dictionaryWithObject:number forKey:@"number"]);
    }];
    
    // console.*
    [self registerHandler:@"console.log" handler:^(id data, BTResponseCallback responseCallback) {
        
    }];
    
    // push.*
    [self registerHandler:@"push.register" handler:^(id data, BTResponseCallback responseCallback) {
        [self registerForPush:responseCallback];
    }];
    
    // menu.*
    [self registerHandler:@"menu.show" handler:^(id data, BTResponseCallback responseCallback) {
        [self showMenu:data callback:responseCallback];
    }];
    
    // device.*
    [self registerHandler:@"device.vibrate" handler:^(id data, BTResponseCallback responseCallback) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }];
    
    // version.*
//    [self registerHandler:@"version.download" handler:^(id data, BTResponseCallback callback) {
//        [self downloadAppVersion:data callback:callback];
//    }];
    
    // viewport.*
    [self registerHandler:@"viewport.expand" handler:^(id data, BTResponseCallback responseCallback) {
        [self _expandViewport:[[data objectForKey:@"height"] floatValue]];
    }];
    [self registerHandler:@"viewport.putOverKeyboard" handler:^(id data, BTResponseCallback responseCallback) {
        [self putWindowOverKeyboard];
    }];
    [self registerHandler:@"viewport.putUnderKeyboard" handler:^(id data, BTResponseCallback responseCallback) {
        [self putWindowUnderKeyboard];
    }];
    
    
    [self registerHandler:@"BTLocale.getCountryCode" handler:^(id data, BTResponseCallback responseCallback) {
        responseCallback(nil, [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]);
    }];
    
    
    [self registerHandler:@"BT.setStatusBar" handler:^(id data, BTResponseCallback responseCallback) {
        [self _setStatusBar:data responseCallback:responseCallback];
    }];
    
    [self registerHandler:@"BT.readResouce" handler:^(id data, BTResponseCallback responseCallback) {
        NSString *path = [[NSBundle mainBundle] pathForResource:data[@"name"] ofType:data[@"type"]];
        responseCallback(nil, [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]);
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

- (void) _setStatusBar:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback {
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
//- (void)downloadAppVersion:(NSDictionary *)data callback:(BTResponseCallback)callback {
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

/* Push API
 **********/
- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString * tokenAsString = [[[deviceToken description]
                                 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] 
                                stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSDictionary* info = [NSDictionary dictionaryWithObject:tokenAsString forKey:@"deviceToken"];
    [self notify:@"push.registered" info:info];
    if (_pushRegistrationResponseCallback) {
        _pushRegistrationResponseCallback(nil, info);
        _pushRegistrationResponseCallback = nil;
    }
}     

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Push registration failure %@", err);
    [self notify:@"push.registerFailed" info:nil];
    if (_pushRegistrationResponseCallback) {
        _pushRegistrationResponseCallback(@"Notifications were not allowed.", nil);
        _pushRegistrationResponseCallback = nil;
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

- (BOOL)isRetina {
    return ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0);
}

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

- (void)showMenu:(NSDictionary *)data callback:(BTResponseCallback)callback {
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

- (void)registerHandler:(NSString *)handlerName handler:(BTHandler)handler {
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
