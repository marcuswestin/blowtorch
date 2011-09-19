#import "BlowTorch.h"

@implementation BlowTorchAppDelegate

@synthesize window, webView, javascriptBridge;

/* API
 *****/
- (void) handleCommand:(NSString*)command withData:(NSDictionary*)data andCallbackID:(NSString*)callbackID {
    [NSException raise:@"BlowTorch abstract method" format:@" handleCommand:withData:andCallbackID must be overridden"];
}


/* Webview messaging
 *******************/
- (void) handleMessage:(NSString *)messageString {
    NSDictionary* message = [messageString objectFromJSONString];
    NSString *callbackID = [message objectForKey:@"callbackID"];
    NSString *command = [message objectForKey:@"command"];
    NSDictionary *data = [message objectForKey:@"data"];
    [self handleCommand:command withData:data andCallbackID:callbackID];
}

/* App lifecycle
 ***************/
- (void) createWebView {
    webView = [[UIWebView alloc] initWithFrame:self.window.bounds];
    [window addSubview:webView];
    javascriptBridge = [WebViewJavascriptBridge createWithDelegate:self];
    webView.delegate = javascriptBridge;
    [webView loadHTMLString:
     @"<!doctype html>"
     "<html><head></head><body><script>"
     "  document.addEventListener('WebViewJavascriptBridgeReady', function() {"
     "      __bridgeIsReady = true;"
     "      if (window.__onBridgeReady) { window.__onBridgeReady(); }"
     "  }, false);"
     "<script src='http://localhost:1234/require/app-ios></script>"
     "</script></body></html>" baseURL:nil];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    [self createWebView];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /* Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state. Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game. */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    /* Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits. */
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    /* Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background. */
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /* Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface. */
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /* Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:. */
}

@end
