#import <UIKit/UIKit.h>
#import "JSONKit.h"
#import "WebViewJavascriptBridge.h"
#import "AFNetworking.h"

typedef void (^ResponseCallback)(NSString* errorMessage, NSDictionary* response);

@interface BlowTorchInterceptionCache : NSURLCache
@end

@interface BlowTorch : NSObject <WebViewJavascriptBridgeDelegate>

/* API
 *****/
- (void) handleCommand:(NSString*)command data:(NSDictionary*)data responseCallback:(ResponseCallback)responseCallback;

/* Upgrade API
 *************/
- (void) requestUpgrade;

/* Private
 *********/
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;
@property (strong, nonatomic) BlowTorchInterceptionCache* interceptionCache;

- (void) loadPage;

@end


