//
//  BTApp.m
//  dogo
//
//  Created by Marcus Westin on 6/14/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTApp.h"
#import "BTViewController.h"

#ifdef DEBUG
#import "DebugUIWebView.h"
#endif

@implementation BTApp {
    UIWebView* _webView;
    UILabel* _reloadView;
    NSDictionary* _launchNotification;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];

    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
#if defined(DEBUG) && defined(__IPHONE_5_0) && !defined(__IPHONE_7_0)
    [NSClassFromString(@"WebView") performSelector:@selector(_enableRemoteInspector)];
#endif

    
    [self _registerNotificationHandlers];
    [self _createWindowAndWebView];
//    [BTSplashScreen show];
    
    [self _baseStartWithWebView:_webView delegate:self server:@"https://dogo.co"];

    if ([self.mode isEqualToString:@"DEBUG"]) {
        [self _renderDevTools];
    }
    
    return YES;
}



/* Platform specific implementations
 ***********************************/
- (void)_platformLoadWebView:(NSString *)url {
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}

- (void)_platformAddSubview:(UIView *)view {
    [_webView addSubview:view];
}

/* Platform setup
 ****************/
- (void)_createWindowAndWebView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    CGRect viewRect;
    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        viewRect = screenBounds;
        NSString *version = [[UIDevice currentDevice] systemVersion];
        BOOL isBefore7 = [version floatValue] < 7.0;
        
        if (isBefore7) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent];
        }
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    } else {
        viewRect = CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);
    }

    self.window = [[UIWindow alloc] initWithFrame:screenBounds];
    self.window.rootViewController = [[BTViewController alloc] init];
    self.window.backgroundColor = [UIColor whiteColor];

#ifdef DEBUG
    UIWebView* webView = _webView = [[DebugUIWebView alloc] initWithFrame:viewRect];
#else
    UIWebView* webView = _webView = [[UIWebView alloc] initWithFrame:viewRect];
#endif
    if ([webView respondsToSelector:@selector(suppressesIncrementalRendering:)]) {
        webView.suppressesIncrementalRendering = YES;
    }
    if ([webView respondsToSelector:@selector(keyboardDisplayRequiresUserAction)]) {
        webView.keyboardDisplayRequiresUserAction = NO;
    }
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
    // we need to handle viewForZoomingInScrollView to avoid shifting the webview contents
    // when a webview text input gains focus and becomes the first responder.
    webView.scrollView.delegate = self;

    [self.window.rootViewController.view addSubview:webView];
    [self.window makeKeyAndVisible];
}

-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return nil;
}

/* Notification Center listeners
 *******************************/
- (void)_registerNotificationHandlers {
    NSNotificationCenter* notifications = [NSNotificationCenter defaultCenter];
    [notifications addObserver:self selector:@selector(_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}

/* Dev reload button
 *******************/
-(void)_renderDevTools {
    _reloadView = [[UILabel alloc] initWithFrame:CGRectMake(320-45,60,40,40)];
    _reloadView.userInteractionEnabled = YES;
    _reloadView.text = @"R";
    _reloadView.textAlignment = NSTextAlignmentCenter;
    _reloadView.backgroundColor = [UIColor whiteColor];
    _reloadView.alpha = 0.07;
    [_reloadView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_reloadTap)]];
    [self.window.rootViewController.view addSubview:_reloadView];
}
-(void)_reloadTap {
    [BTApp reload];
    _reloadView.backgroundColor = [UIColor blueColor];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        _reloadView.backgroundColor = [UIColor whiteColor];
    });
}


/* Remove the UIWebView keyboard accessory
 *****************************************/
- (void)_keyboardWillShow:(NSNotification *)notification {
    [self _putWindowOverKeyboard];
    [self _removeWebViewKeyboardBar];
    [self performSelector:@selector(_removeWebViewKeyboardBarAndShow) withObject:nil afterDelay:0];
}
- (void) _putWindowOverKeyboard {
    self.window.windowLevel = UIWindowLevelStatusBar - 0.1;
}
- (void)_putWindowUnderKeyboard {
    self.window.windowLevel = UIWindowLevelNormal;
}
- (void)_removeWebViewKeyboardBarAndShow {
    [self _removeWebViewKeyboardBar];
    [self _putWindowUnderKeyboard];
}
- (void)_removeWebViewKeyboardBar {
    UIWindow *keyboardWindow = nil;
    for (UIWindow *testWindow in [[UIApplication sharedApplication] windows]) {
        if (![[testWindow class] isEqual:[UIWindow class]]) {
            keyboardWindow = testWindow;
            break;
        }
    }
    if (!keyboardWindow) { return; }
    for (UIView *possibleTarget in [keyboardWindow subviews]) {
        if ([[possibleTarget description] rangeOfString:@"<UIPeripheralHostView:"].location == NSNotFound) { return; }
        for (UIView *subviewWhichIsPossibleFormView in [possibleTarget subviews]) {
            if ([[subviewWhichIsPossibleFormView description] rangeOfString:@"<UIImageView:"].location != NSNotFound) {
                // ios6 on retina phone adds a drop shadow to the UIWebFormAccessory. Hide it.
                subviewWhichIsPossibleFormView.frame = CGRectMake(0,0,0,0);
            } else if ([[subviewWhichIsPossibleFormView description] rangeOfString:@"UIWebFormAccessory"].location != NSNotFound) {
                // This is the "prev/next/done" bar
                [subviewWhichIsPossibleFormView removeFromSuperview];
            }
        }
    }
}

@end





//
//- (void) startup {
//#ifdef DEBUG
//    mode = @"DEBUG";
//    NSString* protocol = @"http:";
//    NSString* port = @"9000";
//    NSString* devHostFile = [[NSBundle mainBundle] pathForResource:@"dev-hostname" ofType:@"txt"];
//    NSString* host = [[NSString stringWithContentsOfFile:devHostFile encoding:NSUTF8StringEncoding error:nil] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
//    //        [WebViewJavascriptBridge enableLogging];
//#else
//    NSString* protocol = @"https:";
//    NSString* port = nil;
//    NSString* host = @"dogo.co";
//#ifdef TESTFLIGHT
//    mode = @"TESTFLIGHT";
//#else
//    mode = @"DISTRIBUTION";
//#endif
//#endif
//    
//    [self setServerScheme:protocol host:host port:port];
//    
//    useLocalBuild = ![mode isEqualToString:@"DEBUG"];
//    self.config[@"mode"] = mode;
//    self.config[@"protocol"] = protocol;
//    self.config[@"serverHost"] = self.serverHost;
//    self.config[@"serverUrl"] = self.serverUrl;
//
//}
//
//
//+ (void)reload {
//    [super reload];
//    [self putWindowUnderKeyboard];
//}
//
//- (void)applicationWillResignActive:(UIApplication *)application {
////    [self notify:@"app.willResignActive"];
//    /*
//     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
//     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
//     */
//}
//
//- (void)applicationDidEnterBackground:(UIApplication *)application {
////    [self notify:@"app.didEnterBackground"];
//    /*
//     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
//     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
//     */
//}
//
//- (void)applicationWillEnterForeground:(UIApplication *)application {
////    [self notify:@"app.willEnterForeground"];
//}
//
//- (void)applicationDidBecomeActive:(UIApplication *)application {
//    [self notify:@"app.didBecomeActive"];
//}
//
//- (void)applicationWillTerminate:(UIApplication *)application {
////    [self notify:@"app.willTerminate"];
//    /*
//     Called when the application is about to terminate.
//     Save data if appropriate.
//     See also applicationDidEnterBackground:.
//     */
//}
//
//

//
//- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
//    NSView* contentView = _window.contentView;
//    _webView = [[WebView alloc] initWithFrame:contentView.frame];
//    [_webView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
//    [contentView addSubview:_webView];
//
//    NSString* server = @"http://localhost:9000";
//    [self _baseStartWithWebView:_webView delegate:self server:server mode:@"DEBUG"];
//}
//
//- (void)_platformLoadWebView:(NSString*)url {
//    _webView.mainFrameURL = url;
//}
//
//- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
//    NSAlert *alert = [[NSAlert alloc] init];
//    [alert addButtonWithTitle:@"OK"];
//    [alert setMessageText:message];
//    [alert runModal];
//}


////#define TESTFLIGHT
////#undef DEBUG
//
//#import <AddressBook/AddressBook.h>
//
//#import "AppDelegate.h"
////#import "UIDeviceHardware.h"
////#import "BTImage.h"
////#import "BTFiles.h"
////#import "Base64.h"
////#import "BTCache.h"
////#import "BTAddressBook.h"
////#import "BTCamera.h"
////#import "BTSql.h"
////#import "BTNet.h"
////#import "BTNotifications.h"
////#import "NSFileManager+Tar.h"
////#import "BTVideo.h"
//
//@implementation AppDelegate
////{
////    NSDictionary* _scheduledInstallParams;
////    BOOL _reloadOnActive;
////}
//
////- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
////    NSLog(@"application openUrl %@ %@", url, url.scheme);
////    if ([url.scheme isEqualToString:@"dogo"]) {
////        [BTApp notify:@"app.didOpenUrl" info:@{ @"url":url.absoluteString, @"sourceApplication":sourceApplication }];
////        return YES;
////    }
////    return NO;
////}
////
////static BOOL useLocalBuild;
////static NSString* mode;
////
////- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
////    if (![super application:application didFinishLaunchingWithOptions:launchOptions]) {
////        return NO;
////    }
////
////    [self setupApp];
////
////    self.window.backgroundColor = [UIColor colorWithRed:230.0f green:230.0f blue:234.0f alpha:1];
////    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:YES];
////
////    return YES;
////}
////
////static NSMutableDictionary* resourceCache;
////static NSString* appVersionDoc;
////
////- (void) startApp {
////    if (useLocalBuild) {
////
////        NSString* iOSVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
////        appVersionDoc = [BTFiles documentPath:[NSString stringWithFormat:@"AppVer-%@.info", iOSVersion]];
////        resourceCache = [NSMutableDictionary dictionary];
////
////        NSDictionary* installedVersion = [NSDictionary dictionaryWithContentsOfFile:appVersionDoc];
////        if (installedVersion && [[NSFileManager defaultManager] fileExistsAtPath:installedVersion[@"path"] isDirectory:YES]) {
////            resourceDir = installedVersion[@"path"];
////        } else {
////            resourceDir = [[NSBundle mainBundle] pathForResource:@"dogo-client-build" ofType:nil];
////        }
////
////        NSLog(@"Start app with resourceDir=%@ (installedVersion=%@)", resourceDir, installedVersion);
////    }
////    [super startApp];
////}
////
////- (void)setupHandlers {
////    [super setupHandlers];
////
////    if (useLocalBuild) {
////        [WebViewProxy handleRequestsWithHost:self.serverHost pathPrefix:@"/resources/" handler:^(NSURLRequest *req, WVPResponse *res) {
////            NSString* resource = req.URL.path;
////            if (!resourceCache[resource]) {
////                NSString* path = [resourceDir stringByAppendingPathComponent:resource];
////                NSData* data = [NSData dataWithContentsOfFile:path];
////                if (!data) {
////                    NSLog(@"ERROR Could not find resource %@", path);
////                    [res respondWithError:404 text:[NSString stringWithFormat:@"Could not find %@", resource]];
////                    return;
////                }
////                resourceCache[resource] = data;
////            }
////            [res respondWithData:resourceCache[resource] mimeType:nil];
////        }];
////    }
////
////    [self handleCommand:@"lookupPersonInfo" handler:^(id params, BTCallback callback) {
////        [self _lookupPersonInfo:params callback:callback];
////    }];
////
////    [self handleCommand:@"AppVersion.scheduleInstall" handler:^(id params, BTCallback callback) {
////        _scheduledInstallParams = params;
////        callback(nil,nil);
////        NSLog(@"Scheduled install");
////    }];
////
////    [self handleCommand:@"AppVersion.installAndReload" handler:^(id params, BTCallback callback) {
////        [self showSplashScreen:params callback:^(id err, id responseData) {
////            [self _installVersion:params callback:^(id err, id responseData) {
////                if (err) { return callback(err, nil); }
////                [self reloadApp];
////            }];
////        }];
////    }];
////
////    [self handleCommand:@"log" handler:^(id params, BTCallback callback) {
////        NSLog(@"ClientLog %@ | %@ | %@", params[@"name"], params[@"caller"] ? params[@"caller"] : @"(?)", [params[@"args"] toJson]);
////    }];
////}
////
////- (void) _installVersion:(NSDictionary*)params callback:(BTCallback)callback {
////    NSData* tarData = [BTFiles read:params];
////    if (!tarData || tarData.length == 0) { return callback(@"Version file not found", nil); }
////    NSString* versionDirectory = [[[BTFiles documentPath:@"AppVersions"] stringByAppendingPathComponent:params[@"document"]] stringByDeletingPathExtension];
////    NSError *error;
////    [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:versionDirectory withTarData:tarData error:&error];
////    if (error) {
////        NSLog(@"Error untarring version %@", error);
////        return callback(@"Error untarring version", nil);
////    }
////    NSDictionary* latestAppVersion = @{ @"path":versionDirectory };
////    BOOL success = [latestAppVersion writeToFile:appVersionDoc atomically:YES];
////    if (!success) {
////        return callback(@"Could not write app version document", nil);
////    }
////
////    _scheduledInstallParams = nil;
////    callback(nil, nil);
////}
////
////- (void)applicationWillResignActive:(UIApplication *)application {
////    if (_scheduledInstallParams) {
////        NSLog(@"Executing scheduled install");
////        [self _installVersion:_scheduledInstallParams callback:^(id err, id responseData) {
////            if (err) {
////                NSLog(@"ERROR executing scheduled install %@", err);
////                [self notify:@"AppVersion.installError" info:err];
////            } else {
////                NSLog(@"Scheduled install completed");
////                _reloadOnActive = YES;
////                [self showSplashScreen:@{} callback:NULL];
////                [self notify:@"AppVersion.installComplete"];
////            }
////        }];
////    }
////    [super applicationWillResignActive:application];
////}
////
////- (void)applicationWillEnterForeground:(UIApplication *)application {
////    if (_reloadOnActive) {
////        _reloadOnActive = NO;
////        [self reloadApp];
////    }
////    [super applicationWillEnterForeground:application];
////}
////
////
////// Commands
////- (void)_lookupPersonInfo:(NSDictionary*)params callback:(BTCallback)callback {
////    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
////    if (!addressBook) { return callback(@"Could not open address book", nil); }
////    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
////        if (!granted) { return callback(@"Give Dogo access to your address book in Settings -> Privacy -> Contacts", nil); }
////        if (error) { return callback(CFBridgingRelease(error), nil); }
////        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
////        CFIndex count = ABAddressBookGetPersonCount(addressBook);
////
////        BOOL isPhone = !!params[@"phoneNumber"];
////        NSString* needle = isPhone ? params[@"phoneNumber"] : params[@"emailAddress"];
////        NSDictionary* res = nil;
////        for (int i=0; i<count; i++ ) {
////            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, i);
////
////            ABMultiValueRef haystack = ABRecordCopyValue(person, isPhone ? kABPersonPhoneProperty : kABPersonEmailProperty);
////
////            // If the contact has multiple phone numbers, iterate on each of them
////            for (int i = 0; i < ABMultiValueGetCount(haystack) && !res; i++) {
////                NSString* valueInHaystack = (__bridge NSString*)ABMultiValueCopyValueAtIndex(haystack, i);
////
////                if ([valueInHaystack isEqualToString:needle]) {
////                    ABMultiValueRef emailProperty = ABRecordCopyValue(person, kABPersonEmailProperty);
////                    NSArray *emailArray = (__bridge NSArray *)(ABMultiValueCopyArrayOfAllValues(emailProperty));
////                    if (!emailArray) { emailArray = @[]; }
////
////                    ABMultiValueRef phoneProperty = ABRecordCopyValue(person, kABPersonPhoneProperty);
////                    NSArray *phoneArray = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(phoneProperty);
////                    if (!phoneArray) { phoneArray = @[]; }
////
////                    NSString *firstName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
////                    NSString *lastName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
////                    NSString* recordId = [NSString stringWithFormat:@"%d", ABRecordGetRecordID(person)];
////                    NSNumber* hasImage = [NSNumber numberWithBool:ABPersonHasImageData(person)];
////
////                    NSDate* birthdayDate = (__bridge NSDate *)(ABRecordCopyValue(person, kABPersonBirthdayProperty));
////                    NSArray* birthday = nil;
////                    if (birthdayDate) {
////                        NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:birthdayDate];
////                        birthday = @[
////                                     [NSNumber numberWithInt:[components day]],
////                                     [NSNumber numberWithInt:[components month]],
////                                     [NSNumber numberWithInt:[components year]]];
////                    }
////
////                    res = @{
////                            @"recordId":recordId,
////                            @"firstName":firstName ? firstName : @"",
////                            @"lastName":lastName ? lastName : @"",
////                            @"emailAddresses":emailArray,
////                            @"phoneNumbers":phoneArray,
////                            @"hasImage":hasImage,
////                            @"birthday":birthday ? birthday : [NSNumber numberWithBool:NO]
////                            };
////                    break;
////                }
////            }
////        }
////        callback(nil, res);
////        CFRelease(addressBook);
////        CFRelease(allPeople);
////    });
////}
//
//@end














//#import "BTAppDelegate.h"
//#import "NSFileManager+Tar.h"
//#import "BTViewController.h"
//#import "UIColor+Util.h"
//
//#ifdef DEBUG
//#import "DebugUIWebView.h"
//#endif
//
////static BTAppDelegate* instance;
////
////@implementation BTAppDelegate {
////    NSString* _serverScheme;
////    NSString* _serverHost;
////    NSString* _serverPort;
////    UILabel* _reloadView;
////    BTCallback _menuCallback;
////    NSDictionary* _launchNotification;
////    UIView* _splashScreen;
////
////}
//
////@synthesize window, webView, javascriptBridge=_bridge, config;
//
////+ (BTAppDelegate *)instance { return instance; }
//
///* App lifecycle
// **********************/
////- (void)setupModules {}
//
////- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
////    instance = self;
////    config = [NSMutableDictionary dictionary];
////
////    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
////
////    [self createWindowAndWebView];
////    [self showSplashScreen:@{} callback:NULL];
////
////#if defined(DEBUG) && defined(__IPHONE_5_0) && !defined(__IPHONE_7_0)
////    [NSClassFromString(@"WebView") performSelector:@selector(_enableRemoteInspector)];
////#endif
////
////    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
////
////    NSNotificationCenter* notifications = [NSNotificationCenter defaultCenter];
////    [notifications addObserver:self selector:@selector(didRotate:) name:@"UIDeviceOrientationDidChangeNotification" object:nil];
////    [notifications addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
////    [notifications addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
////    [notifications addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
////
////
////    _launchNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
////
////    return YES;
////}
//
////- (void)setServerScheme:(NSString*)scheme host:(NSString *)host port:(NSString *)port {
////    _serverScheme = scheme;
////    _serverHost = host;
////    _serverPort = port;
////}
//
////- (NSString *)serverHost {
////    return _serverHost;
////}
//
////- (NSString*) serverUrl {
////    if (_serverPort) { return [_serverScheme stringByAppendingFormat:@"//%@:%@", _serverHost, _serverPort]; }
////    else { return [_serverScheme stringByAppendingFormat:@"//%@", _serverHost]; }
////}
//
////-(void)setupApp {
////#ifdef DEBUG
////    [self _renderDevTools];
////#endif
////
////    [self setupHandlers];
////    [self setupModules];
////    [self startApp];
////}
//
////-(void)_renderDevTools {
////    _reloadView = [[UILabel alloc] initWithFrame:CGRectMake(320-45,60,40,40)];
////    _reloadView.userInteractionEnabled = YES;
////    _reloadView.text = @"R";
////    _reloadView.font = [UIFont fontWithName:@"Open Sans" size:20];
////    _reloadView.textAlignment = NSTextAlignmentCenter;
////    _reloadView.backgroundColor = [UIColor whiteColor];
////    _reloadView.alpha = 0.05;
////    [_reloadView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_reloadTap)]];
////    [window.rootViewController.view addSubview:_reloadView];
////}
////-(void)_reloadTap {
////    NSLog(@"\n\n\nRELOAD APP\n\n");
////    [self reloadApp];
////    _reloadView.backgroundColor = [UIColor blueColor];
////    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
////    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
////        _reloadView.backgroundColor = [UIColor whiteColor];
////    });
////}
//
////-(void)startApp {
////    [_bridge reset];
////    NSURL* appHtmlUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/resources/app.html", self.serverUrl]];
////    [webView loadRequest:[NSURLRequest requestWithURL:appHtmlUrl]];
////    NSString* bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
////    NSString* client = [@"ios-" stringByAppendingString:bundleVersion];
////    [self notify:@"app.init" info:@{ @"config":config, @"client":client }];
////
////    [self putWindowUnderKeyboard];
////}
//
//- (void)applicationWillResignActive:(UIApplication *)application {
//    [self notify:@"app.willResignActive"];
//    /*
//     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
//     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
//     */
//}
//
//- (void)applicationDidEnterBackground:(UIApplication *)application {
//    [self notify:@"app.didEnterBackground"];
//    /*
//     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
//     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
//     */
//}
//
//- (void)applicationWillEnterForeground:(UIApplication *)application {
//    [self notify:@"app.willEnterForeground"];
//}
//
//- (void)applicationDidBecomeActive:(UIApplication *)application {
//    [self notify:@"app.didBecomeActive"];
//}
//
//- (void)applicationWillTerminate:(UIApplication *)application {
//    [self notify:@"app.willTerminate"];
//    /*
//     Called when the application is about to terminate.
//     Save data if appropriate.
//     See also applicationDidEnterBackground:.
//     */
//}
//
//
///* Native events notifications
// *****************************/
//
//-(void) didRotate:(NSNotification*)notification {
//    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
//    NSInteger deg = 0;
//    if (orientation == UIDeviceOrientationPortraitUpsideDown) {
//        deg = 180;
//    } else if (orientation == UIDeviceOrientationLandscapeLeft) {
//        deg = 90;
//    } else if (orientation == UIDeviceOrientationLandscapeRight) {
//        deg = -90;
//    }
//    NSNumber* degNum = [NSNumber numberWithInt:deg];
//    [self notify:@"device.rotated" info:[NSDictionary dictionaryWithObject:degNum forKey:@"deg"]];
//}
//
//- (void)keyboardWillShow:(NSNotification *)notification {
//    [BTAppDelegate.instance putWindowOverKeyboard];
//    [self _removeWebViewKeyboardBar];
//    [self performSelector:@selector(_removeWebViewKeyboardBar) withObject:nil afterDelay:0];
////    [self notify:@"keyboard.willShow" info:[self _keyboardEventInfo:notification]];
//}
//- (void)keyboardWillHide:(NSNotification *)notification {
//    [self notify:@"keyboard.willHide" info:[self _keyboardEventInfo:notification]];
//}
//- (void)keyboardDidHide:(NSNotification*)notification {
//    [self notify:@"keyboard.didHide" info:[self _keyboardEventInfo:notification]];
//}
//- (NSDictionary *)_keyboardEventInfo:(NSNotification *)notification {
//    NSDictionary *userInfo = [notification userInfo];
//    NSValue *keyboardAnimationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
//    NSTimeInterval keyboardAnimationDurationInterval;
//    [keyboardAnimationDurationValue getValue:&keyboardAnimationDurationInterval];
//    NSNumber* keyboardAnimationDuration = [NSNumber numberWithDouble:keyboardAnimationDurationInterval];
//    return [NSDictionary dictionaryWithObject:keyboardAnimationDuration forKey:@"keyboardAnimationDuration"];
//}
//
//
///* WebView <-> Native API
// ************************/
//- (void)setupHandlers {
//    // app.*
//    [self handleCommand:@"app.reload" handler:^(id data, BTCallback responseCallback) {
//        [self reloadApp:data];
//    }];
//    [self handleCommand:@"splashScreen.hide" handler:^(id data, BTCallback  responseCallback) {
//        [self hideSplashScreen:data];
//        if (_launchNotification) {
//            [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didLaunchWithNotification" object:nil userInfo:@{ @"launchNotification":_launchNotification }];
//            _launchNotification = nil;
//        }
//    }];
//    [self handleCommand:@"splashScreen.show" handler:^(id params, BTCallback callback) {
//        [self showSplashScreen:params callback:callback];
//    }];
//    [self handleCommand:@"app.setIconBadgeNumber" handler:^(id data, BTCallback responseCallback) {
//        NSNumber* number = [data objectForKey:@"number"];
//        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[number intValue]];
//    }];
//    [self handleCommand:@"app.getIconBadgeNumber" handler:^(id data, BTCallback responseCallback) {
//        NSNumber* number = [NSNumber numberWithInt:[[UIApplication sharedApplication] applicationIconBadgeNumber]];
//        responseCallback(nil, [NSDictionary dictionaryWithObject:number forKey:@"number"]);
//    }];
//
//    // device.*
//    [self handleCommand:@"device.vibrate" handler:^(id data, BTCallback responseCallback) {
//        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
//    }];
//
//    // viewport.*
//    [self handleCommand:@"viewport.expand" handler:^(id data, BTCallback responseCallback) {
//        float addHeight = [data[@"height"] floatValue];
//        float normalHeight = [[UIScreen mainScreen] bounds].size.height;
//        CGRect frame = webView.frame;
//        webView.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, normalHeight + addHeight);
//    }];
//    [self handleCommand:@"viewport.putOverKeyboard" handler:^(id data, BTCallback responseCallback) {
//        [self putWindowOverKeyboard];
//    }];
//    [self handleCommand:@"viewport.putUnderKeyboard" handler:^(id data, BTCallback responseCallback) {
//        [self putWindowUnderKeyboard];
//    }];
//
//    [self handleCommand:@"BTLocale.getCountryCode" handler:^(id data, BTCallback responseCallback) {
//        responseCallback(nil, [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]);
//    }];
//
//    [self handleCommand:@"BT.setStatusBar" handler:^(id data, BTCallback callback) {
//        [self setStatusBar:data callback:callback];
//    }];
//}
//
//- (void)reloadApp { [self reloadApp:nil]; }
//- (void)reloadApp:(NSDictionary*)data {
//    [self setStatusBar:@{ @"visible":[NSNumber numberWithBool:NO], @"animation":@"slide" } callback:^(id err, id responseData) {}];
//    [self showSplashScreen:@{ @"fade":[NSNumber numberWithDouble:0.25] } callback:^(id err, id responseData) {
//        [self startApp];
//    }];
//}
//
//- (void)setStatusBar:(NSDictionary*)data callback:(BTCallback)callback {
//    UIStatusBarAnimation animation = UIStatusBarAnimationNone;
//    if ([data[@"animation"] isEqualToString:@"fade"]) { animation = UIStatusBarAnimationFade; }
//    if ([data[@"animation"] isEqualToString:@"slide"]) { animation = UIStatusBarAnimationSlide; }
//    BOOL hidden = ![data[@"visible"] boolValue];
//    [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animation];
//    callback(nil,nil);
//}
//
//+ (void)notify:(NSString *)name info:(NSDictionary *)info { [instance notify:name info:info]; }
//+ (void)notify:(NSString *)name { [instance notify:name]; }
//- (void)notify:(NSString *)event { [self notify:event info:NULL]; }
//- (void)notify:(NSString *)event info:(id)info {
////    NSLog(@"Notify %@ %@", event, info);
//    if (!info) { info = [NSDictionary dictionary]; }
//
//    if ([info isKindOfClass:[NSError class]]) {
//        info = [NSDictionary dictionaryWithObjectsAndKeys:[info localizedDescription], @"message", nil];
//    }
//    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:event object:nil userInfo:info]];
//    [_bridge send:[NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil]];
//}
//
//
///* Misc API
// **********/
//
//- (void)handleCommand:(NSString *)handlerName handler:(BTCommandHandler)handler {
//    [self.javascriptBridge registerHandler:handlerName handler:^(id data, WVJBResponseCallback responseCallback) {
//        NSLog(@"Handle command %@", handlerName);
//        NSString* async = data ? data[@"async"] : nil;
//        if (async) {
//            dispatch_queue_t queue;
//            if ([async isEqualToString:@"main"]) {
//                queue = dispatch_get_main_queue();
//            } else if ([async isEqualToString:@"high"]) {
//                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
//            } else if ([async isEqualToString:@"low"]) {
//                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
//            } else if ([async isEqualToString:@"background"]) {
//                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
//            } else {
//                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//            }
//            dispatch_async(queue, ^{
//                [self _doHandleCommand:handlerName handler:handler data:data responseCallback:responseCallback];
//            });
//        } else {
//            [self _doHandleCommand:handlerName handler:handler data:data responseCallback:responseCallback];
//        }
//    }];
//}
//
//- (void)_doHandleCommand:(NSString*)handlerName handler:(BTCommandHandler)handler data:(NSDictionary*)data responseCallback:(WVJBResponseCallback)responseCallback {
//    @try {
//        handler(data, ^(id err, id responseData) {
//            NSLog(@"Respond command %@", handlerName);
//            if (err) {
//                if ([err isKindOfClass:[NSError class]]) {
//                    err = @{ @"message":[err localizedDescription] };
//                }
//                responseCallback(@{ @"error":err });
//            } else if (responseData) {
//                responseCallback(@{ @"responseData":responseData });
//            } else {
//                responseCallback(@{});
//            }
//        });
//    } @catch (NSException *exception) {
//        NSLog(@"WARNING: handleCommand:%@ threw with params:%@ error:%@", handlerName, data, exception);
//        responseCallback(@{ @"error": @{ @"message":exception.name, @"reason":exception.reason }});
//    }
//}
//
//- (void)handleRequests:(NSString *)command handler:(BTRequestHandler)requestHandler {
//    [WebViewProxy handleRequestsWithHost:self.serverHost path:command handler:^(NSURLRequest *req, WVPResponse *res) {
//        NSDictionary* params = [req.URL.query parseQueryParams];
//        requestHandler(params, res);
//    }];
//}
//
//- (void)_respond:(WVPResponse*)res fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
//    NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
//    NSData* data = [NSData dataWithContentsOfFile:filePath];
//    [res respondWithData:data mimeType:mimeType];
//}
//
//
//- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
//    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
//        [[UIApplication sharedApplication] openURL:[request URL]];
//        return NO;
//    }
//    return YES;
//}
//
//
//
//
//@end
//
//
////[BTApp handleCommand:@"BTImage.saveToPhotosAlbum" handler:^(id params, BTCallback callback) {
////    [self _saveToPhotosAlbum:params callback:callback];
////}];
////- (void)_saveToPhotosAlbum:(NSDictionary*)params callback:(BTCallback)callback {
////    NSData* data = [BTCache get:params[@"url"] cacheInMemory:params[@"memory"]];
////    if (!data.length) { return callback(@"Image has not been downloaded", nil); }
////    UIImageWriteToSavedPhotosAlbum([UIImage imageWithData:data], nil, nil, nil);
////    callback(nil,nil);
////}
//
