#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge/WebViewJavascriptBridge.h"

@interface BlowTorchAppDelegate : UIResponder <UIApplicationDelegate, WebViewJavascriptBridgeDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;

@end
