#import <UIKit/UIKit.h>
#import "JSONKit.h"
#import "WebViewJavascriptBridge.h"

typedef void (^ResponseCallback)(NSString* errorMessage, NSDictionary* response);

@interface BlowTorchInterceptionCache : NSURLCache
@end

@interface BlowTorchAppDelegate : UIResponder <UIApplicationDelegate, WebViewJavascriptBridgeDelegate>

/* API
 *****/
- (void) handleCommand:(NSString*)command data:(NSDictionary*)data responseCallback:(ResponseCallback)responseCallback;

/* Private
 *********/
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;
@property (strong, nonatomic) BlowTorchInterceptionCache* interceptionCache;

- (void) loadPage;

@end


