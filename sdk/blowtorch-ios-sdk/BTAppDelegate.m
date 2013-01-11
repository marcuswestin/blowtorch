#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "BTIndex.h"

#ifdef DEBUG
#import "DebugUIWebView.h"
#endif

@interface BTAppDelegate (hidden)
- (NSURL*) getUrl:(NSString*) path;
- (NSString*) getFilePath:(NSString*) name;
- (NSString*) getCurrentVersionPath:(NSString*)resourcePath;
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
}

@synthesize window, webView, javascriptBridge=_bridge, state, net, overlay, config, launchNotification,
    cache=_cache, documents=_documents;

+ (BTAppDelegate *)instance { return instance; }

/* App lifecycle
 **********************/
- (void)setupModules {}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    instance = self;
    state = [[BTState alloc] init];
    net = [[BTNet alloc] init];
    config = [NSMutableDictionary dictionary];
    _documents = [[BTCache alloc] initWithDirectory:NSDocumentDirectory];
    _cache = [[BTCache alloc] initWithDirectory:NSCachesDirectory];
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
    }
    
    [self setupBridgeHandlers];
    [self setupNetHandlers];
    [self setupModules];
}

-(void)startApp {
    NSString* downloadedVersion = [self getAppInfo:@"downloadedVersion"];
    if (downloadedVersion) {
        [self setAppInfo:@"installedVersion" value:downloadedVersion];
    }
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

/* WebView <-> Native API
 ************************/
- (void)setupBridgeHandlers {
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
    
    // state.*
    [self registerHandler:@"state.load" handler:^(id data, BTResponseCallback responseCallback) {
        responseCallback(nil, [state load:[data objectForKey:@"key"]]);
    }];
    [self registerHandler:@"state.set" handler:^(id data, BTResponseCallback responseCallback) {
        [state set:[data objectForKey:@"key"] value:[data objectForKey:@"value"]];
        responseCallback(nil, nil);
    }];
    [self registerHandler:@"state.clear" handler:^(id data, BTResponseCallback responseCallback) {
        [state reset];
        responseCallback(nil, nil);
    }];
    
    // push.*
    [self registerHandler:@"push.register" handler:^(id data, BTResponseCallback responseCallback) {
        [self registerForPush:responseCallback];
    }];
    
    // media.*
    [self registerHandler:@"media.pick" handler:^(id data, BTResponseCallback responseCallback) {
        [self pickMedia:data response:[BTResponse responseWithCallback:responseCallback]];
    }];
    
    // menu.*
    [self registerHandler:@"menu.show" handler:^(id data, BTResponseCallback responseCallback) {
        [self showMenu:data response:[BTResponse responseWithCallback:responseCallback]];
    }];
    
    // device.*
    [self registerHandler:@"device.vibrate" handler:^(id data, BTResponseCallback responseCallback) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }];
    
    // version.*
    [self registerHandler:@"version.download" handler:^(id data, BTResponseCallback responseCallback) {
        [self downloadAppVersion:data response:[BTResponse responseWithCallback:responseCallback]];
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

/* Net API
 *********/
- (void)setupNetHandlers {
    NSString* mediaPrefix = @"/blowtorch/media/";
    [WebViewProxy handleRequestsWithHost:self.serverHost pathPrefix:mediaPrefix handler:^(NSURLRequest *req, WVPResponse *res) {
        NSString* file = [req.URL.path substringFromIndex:mediaPrefix.length];
        NSString* format = [file pathExtension];
        NSString* mediaId = [file stringByDeletingPathExtension];
        UIImage* image = [_mediaCache objectForKey:mediaId];
        NSData* data;
        NSString* mimeType;
        if ([format isEqualToString:@"png"]) {
            data = UIImagePNGRepresentation(image);
            mimeType = @"image/png";
        } else if ([format isEqualToString:@"jpg"] || [format isEqualToString:@"jpeg"]) {
            data = UIImageJPEGRepresentation(image, 1.0);
            mimeType = @"image/jpg";
        } else {
            return;
        }
        [res respondWithData:data mimeType:mimeType];
    }];
}

/* Upgrade API
 *************/
- (void)downloadAppVersion:(NSDictionary *)data response:(BTResponse*)response {
    NSString* url = [data objectForKey:@"url"];
    NSDictionary* headers = [data objectForKey:@"headers"];
    NSString* version = [url urlEncodedString];
    NSString* directoryPath = [self getFilePath:[@"versions/" stringByAppendingString:version]];
    [BTNet request:url method:@"GET" headers:headers params:nil responseCallback:^(id error, NSData *tarData) {
        if (error) {
            [response respondWithError:error];
            return;
        }
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

static int uniqueId = 1;
- (NSString *)unique {
    int thisId = ++uniqueId;
    return [NSString stringWithFormat:@"%d", thisId];
}

- (BOOL)isRetina {
    return ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0);
}

@synthesize mediaResponse=_mediaResponse, mediaCache=_mediaCache;
- (void)pickMedia:(NSDictionary*)data response:(BTResponse*)response {
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

    [self putWindowUnderChrome];
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
    [self performSelector:@selector(putWindowOverStatusBar) withObject:nil afterDelay:0.25];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self.window.rootViewController dismissModalViewControllerAnimated: YES];
    [_mediaResponse respondWith:[NSDictionary dictionary]];
    [self performSelector:@selector(putWindowOverStatusBar) withObject:nil afterDelay:0.25];
}

- (void)_createStatusBarOverlay {
    // Put a transparent view on top of the status bar in order to intercept touch 
    [self putWindowOverStatusBar];
    UIView* statusBarOverlay = [[UIView alloc] initWithFrame:[UIApplication sharedApplication].statusBarFrame];
    statusBarOverlay.backgroundColor = [UIColor clearColor];
    [statusBarOverlay addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStatusBarTapped)]];
    window.backgroundColor = [UIColor clearColor];
    [window addSubview:statusBarOverlay];
}

- (void)putWindowOverStatusBar {
    // cause the status bar overlay to intercept status bar touch events
    window.windowLevel = UIWindowLevelStatusBar + 0.1;
}

- (void)putWindowOverKeyboard {
    // cause the keyboard (and its webview accessory - "prev/next/done" toolbar - to render underneath the webview)
    window.windowLevel = UIWindowLevelStatusBar - 0.1;
}

- (void)putWindowUnderChrome {
    window.windowLevel = UIWindowLevelNormal;
}

- (void)showMenu:(NSDictionary *)data response:(BTResponse*)response {
    NSArray* titles = [data objectForKey:@"titles"];
    NSString* title1 = titles.count > 0 ? [titles objectAtIndex:0] : nil;
    NSString* title2 = titles.count > 1 ? [titles objectAtIndex:1] : nil;
    NSString* title3 = titles.count > 2 ? [titles objectAtIndex:2] : nil;
    NSString* title4 = titles.count > 3 ? [titles objectAtIndex:3] : nil;
    
    _menuResponse = response;
    UIActionSheet* sheet = [[UIActionSheet alloc] initWithTitle:[data objectForKey:@"title"] delegate:self cancelButtonTitle:[data objectForKey:@"cancelTitle"] destructiveButtonTitle:[data objectForKey:@"destructiveTitle"] otherButtonTitles:title1, title2, title3, title4, nil];
    [sheet showInView:self.webView];
}

@synthesize menuResponse=_menuResponse;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    [_menuResponse respondWith:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:buttonIndex] forKey:@"index"]];
}

- (void)actionSheetCancel:(UIActionSheet *)actionSheet {
    [_menuResponse respondWith:nil];
}

- (void)registerHandler:(NSString *)handlerName handler:(BTHandler)handler {
    [self.javascriptBridge registerHandler:handlerName handler:^(id data, WVJBResponseCallback responseCallback) {
        handler(data, ^(id err, id responseData) {
            if (err) {
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

- (NSString *)getCurrentVersionPath:(NSString *)resourcePath {
    return [self getFilePath:[NSString stringWithFormat:@"versions/%@/%@", [self getCurrentVersion], resourcePath]];
}

- (NSString *)getFilePath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

-(NSURL *)getUrl:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverUrl, path]];
}

- (void)createWindowAndWebView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame:screenBounds];
    window.backgroundColor = [UIColor clearColor];
    [window makeKeyAndVisible];
    window.rootViewController = [[BTViewController alloc] init];
    
    screenBounds.size.height -= 20;
#ifdef DEBUG
    webView = [[DebugUIWebView alloc] initWithFrame:screenBounds];
#else
    webView = [[UIWebView alloc] initWithFrame:screenBounds];
#endif
    if ([webView respondsToSelector:@selector(setSuppressesIncrementalRendering:)]) {
        [webView setSuppressesIncrementalRendering:YES]; // iOS6 only
    }
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    webView.clipsToBounds = YES;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    webView.scrollView.bounces = NO;
    webView.scrollView.scrollsToTop = NO;
    webView.scrollView.clipsToBounds = YES;
    webView.scrollView.scrollEnabled = NO;
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
