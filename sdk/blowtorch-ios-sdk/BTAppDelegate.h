#import <UIKit/UIKit.h>
#import "JSONKit.h"
#import "WebViewJavascriptBridge.h"
#import "AFNetworking.h"
#import "BTState.h"

typedef void (^ResponseCallback)(id error, NSDictionary* response);

@interface BTAppDelegate : UIResponder <UIApplicationDelegate, WebViewJavascriptBridgeDelegate>

/* Properties
 ************/
@property (strong, atomic) NSString* serverHost;
@property (atomic, strong) BTState* state;
@property (strong, atomic) NSMutableDictionary* config;
- (BOOL) isDev;

/* Lifecycle API
 ***************/
- (void)startApp;

/* Webview API
 *************/
- (void) handleCommand:(NSString*)command data:(NSDictionary*)data responseCallback:(ResponseCallback)responseCallback;
- (void) notify:(NSString*)name info:(NSDictionary*)response;

/* Upgrade API
 *************/
- (void) loadCurrentVersionApp;
- (void) requestUpgrade;

/* Private
 *********/
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;
@property (strong, atomic) UIView* overlay;

@end


@interface BTInterceptionCache : NSURLCache
@property (strong, atomic) BTAppDelegate* blowtorchInstance;
@end
