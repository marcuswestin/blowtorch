#import "BTAppDelegate.h"
#import "NSFileManager+Tar.h"
#import "BTViewController.h"
#import "BTIndex.h"

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

@synthesize window, webView, javascriptBridge, serverHost, state, net, overlay, config, launchNotification, pushRegistrationCallback;

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:@"UIDeviceOrientationDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    
    return YES;
}

-(void)startApp:(BOOL)devMode {
    DEV_MODE = devMode;
    [self.state set:@"installedVersion" value:[self.state get:@"downloadedVersion"]];
    NSLog(@"Starting app with version %@", [self.state get:@"installedVersion"]);
    
    NSURL* url = [self getUrl:@"app.html"];
    [self.javascriptBridge resetQueue];
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
    
    NSString* bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString* client = [bundleVersion stringByAppendingString:@"-ios"];
    NSDictionary* appInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                               config, @"config",
                               client, @"client",
                               nil];
    [self notify:@"app.start" info:appInfo];
}

- (void)registerForPush:(ResponseCallback)responseCallback {
    pushRegistrationCallback = responseCallback;
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
    
    if (![command isEqualToString:@"console.log"]) {
        NSLog(@"command %@", command);
    }
    
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
        [self startApp:DEV_MODE];

    } else if ([command isEqualToString:@"app.show"]) {
        [self hideLoadingOverlay];
        if (launchNotification) {
            [self handlePushNotification:launchNotification didBringAppToForeground:YES];
            launchNotification = nil;
        }
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
        responseCallback(nil, nil);
    
    } else if ([command isEqualToString:@"push.register"]) {
        [self registerForPush:responseCallback];
        
    } else if ([command isEqualToString:@"media.pick"]) {
        [self pickMedia:data responseCallback:responseCallback];

    } else if ([command isEqualToString:@"menu.show"]) {
        [self showMenu:data responseCallback:responseCallback];
        
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

    } else if ([command isEqualToString:@"version.download"]) {
        [self downloadAppVersion:data responseCallback:responseCallback];
        
    } else {
        [self handleCommand:command data:data responseCallback:responseCallback];
    }
}

- (void) handleCommand:(NSString *)command data:(NSDictionary *)data responseCallback:(ResponseCallback)responseCallback {
    [NSException raise:@"BlowTorch abstract method" format:@" handleCommand:data:responseCallback must be overridden"];
}

- (void)notify:(NSString *)event { [self notify:event info:NULL]; }
- (void)notify:(NSString *)event info:(NSDictionary *)info {
    if (![event isEqualToString:@"device.rotated"]) {
        NSLog(@"Notify %@ %@", event, info);
    }
    if (!info) { info = [NSDictionary dictionary]; }
    NSDictionary* message = [NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil];
    [javascriptBridge sendMessage:[message JSONString] toWebView:webView];
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
    
    NSString* prefix = @"/blowtorch/";
    if ([[url path] hasPrefix:prefix]) {
        NSString* path = [[url path] substringFromIndex:prefix.length];
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
        } else if ([[parts objectAtIndex:0] isEqualToString:@"media"]) {
            NSString* format = [[url path] pathExtension];
            NSString* mediaId = [parts.lastObject stringByDeletingPathExtension];
            UIImage* image = [mediaCache objectForKey:mediaId];
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
- (void)downloadAppVersion:(NSDictionary *)data responseCallback:(ResponseCallback)responseCallback {
    NSString* url = [data objectForKey:@"url"];
    NSDictionary* headers = [data objectForKey:@"headers"];
    NSString* version = [url urlEncodedString];
    NSString* directoryPath = [self getFilePath:[@"versions/" stringByAppendingString:version]];
    [BTNet request:url method:@"GET" headers:headers params:nil responseCallback:^(id error, NSDictionary *response) {
        if (error) {
            responseCallback(error, nil);
            return;
        }
        NSData* tarData = [response objectForKey:@"responseData"];
        if (!tarData || tarData.length == 0) {
            NSLog(@"Received download response with no data");
            return;
        }
        NSError *tarError;
        [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:directoryPath withTarData:tarData error:&tarError];
        if (tarError) {
            NSLog(@"Error untarring version %@", error);
            responseCallback(@"Error untarring version", nil);
        } else {
            [self.state set:@"downloadedVersion" value:version];
            NSLog(@"Success downloading and untarring version %@", version);
            responseCallback(nil, nil);
        }
    }];
}

- (NSString *)getCurrentVersion {
    return [self.state get:@"installedVersion"];
}

/* Push API
 **********/
- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString * tokenAsString = [[[deviceToken description]
                                 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] 
                                stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSDictionary* info = [NSDictionary dictionaryWithObject:tokenAsString forKey:@"deviceToken"];
    [self notify:@"push.registered" info:info];
    if (pushRegistrationCallback) {
        pushRegistrationCallback(nil, info);
        pushRegistrationCallback = nil;
    }
}     

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Push registration failure %@", err);
    [self notify:@"push.registerFailed" info:nil];
    if (pushRegistrationCallback) {
        pushRegistrationCallback(@"Notifications were not allowed.", nil);
        pushRegistrationCallback = nil;
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

@synthesize mediaResponseCallback, mediaCache;
- (void)pickMedia:(NSDictionary*)data responseCallback:(ResponseCallback)responseCallback {
    if (!mediaCache) { mediaCache = [NSMutableDictionary dictionary]; }
    
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
        return responseCallback(@"Unknown source", nil);
    }
    
    if ([data objectForKey:@"allowEditing"]) {
        mediaUI.allowsEditing = YES;
    } else {
        mediaUI.allowsEditing = NO;
    }
    
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
    [self.window.rootViewController dismissModalViewControllerAnimated: YES];
    mediaResponseCallback(nil, [NSDictionary dictionary]);
}

- (void)showMenu:(NSDictionary *)data responseCallback:(ResponseCallback)responseCallback {
    menuResponseCallback = responseCallback;
    UIActionSheet* sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    for (NSString* title in [data objectForKey:@"titles"]) {
        [sheet addButtonWithTitle:title];
    }
    [sheet showInView:self.webView];
}

@synthesize menuResponseCallback;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    menuResponseCallback(nil, [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:buttonIndex] forKey:@"index"]);
}

- (void)actionSheetCancel:(UIActionSheet *)actionSheet {
    menuResponseCallback(nil, nil);
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
