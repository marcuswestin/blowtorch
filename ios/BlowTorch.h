#import <UIKit/UIKit.h>
#import "JSONKit.h"
#import "WebViewJavascriptBridge.h"

@interface BlowTorchAppDelegate : UIResponder <UIApplicationDelegate, WebViewJavascriptBridgeDelegate>

/* API
 *****/
- (void) handleCommand:(NSString*)command withData:(NSDictionary*)data andCallbackID:(NSString*)callbackID;

/* Private
 *********/
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;

@end
