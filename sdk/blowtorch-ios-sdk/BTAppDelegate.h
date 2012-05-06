#import <UIKit/UIKit.h>
#import "JSONKit.h"
#import "WebViewJavascriptBridge.h"
#import "AFNetworking.h"
#import "BTState.h"
#import <AudioToolbox/AudioServices.h>

typedef void (^ResponseCallback)(id error, NSDictionary* response);

@interface BTAppDelegate : UIResponder <UIApplicationDelegate, WebViewJavascriptBridgeDelegate>

/* Properties
 ************/
@property (strong, atomic) NSString* serverHost;
@property (atomic, strong) BTState* state;
@property (strong, atomic) NSMutableDictionary* config;
@property (atomic, assign) BOOL isDevMode;

/* Lifecycle API
 ***************/
- (void)startApp:(BOOL)devMode;

/* Webview API
 *************/
- (void) handleCommand:(NSString*)command data:(NSDictionary*)data responseCallback:(ResponseCallback)responseCallback;
- (void) notify:(NSString*)name info:(NSDictionary*)response;

/* Upgrade API
 *************/
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
