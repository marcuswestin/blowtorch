#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "BTIndex.h"

#ifdef DEBUG
#import "DebugUIWebView.h"
#endif

static BOOL DEV_MODE;

@interface BTAppDelegate (hidden)
- (NSURL*) getUrl:(NSString*) path;
- (NSString*) getFilePath:(NSString*) name;
- (NSString*) getCurrentVersionPath:(NSString*)resourcePath;
- (void) createWindowAndWebView;
- (void) showLoadingOverlay;
- (void) hideLoadingOverlay;
- (void)_respond:(WVPResponse*)res fileName:(NSString *)fileName mimeType:(NSString *)mimeType;
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
    [notifications addObserver:self selector:@selector(handleBTNotification:) name:@"bt.notify" object:nil];
    
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

-(void)setupApp:(BOOL)devMode {
    DEV_MODE = devMode;
    if (!devMode) {
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
    // app.*
    [_bridge registerHandler:@"app.restart" handler:^(id data, WVJBResponse* response) {
        [self startApp];
    }];
    [_bridge registerHandler:@"app.show" handler:^(id data,  WVJBResponse* response) {
        [self hideLoadingOverlay];
        if (launchNotification) {
            [self handlePushNotification:launchNotification didBringAppToForeground:YES];
            launchNotification = nil;
        }
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
- (void)setupNetHandlers {
    NSString* btPrefix = @"/blowtorch/";
    [WebViewProxy handleRequestsWithHost:self.serverHost pathPrefix:btPrefix handler:^(NSURLRequest *req, WVPResponse *res) {
        NSString* path = [req.URL.path substringFromIndex:btPrefix.length];
        NSArray* parts = [path componentsSeparatedByString:@"/"];
        if ([[parts objectAtIndex:0] isEqualToString:@"media"]) {
            NSString* format = [req.URL.path pathExtension];
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
                return;
            }
            [res respondWithData:data mimeType:mimeType];
        }
    }];
}

/* Upgrade API
 *************/
- (void)downloadAppVersion:(NSDictionary *)data response:(WVJBResponse *)response {
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
    [self setupNetHandlers];
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
