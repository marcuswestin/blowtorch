#import "BTTypes.h"
#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge_iOS.h"
#import "WebViewProxy.h"
#import <AudioToolbox/AudioServices.h>

#import "NSString+Util.h"

@interface BTAppDelegate : UIResponder <UIApplicationDelegate, UIWebViewDelegate, UIActionSheetDelegate, UIScrollViewDelegate>

+ (BTAppDelegate*) instance;

- (void) handleRequests:(NSString*)path handler:(BTRequestHandler)requestHandler;
- (void) handleCommand:(NSString*)handlerName handler:(BTCommandHandler)handler;

/* Properties
 ************/
@property (strong, atomic) NSMutableDictionary* config;

- (NSString*) serverUrl;
- (NSString*) serverHost;
- (void)setServerScheme:(NSString*)scheme host:(NSString *)host port:(NSString *)port;

/* Lifecycle API
 ***************/
- (void)setupModules;
- (void)startApp;
- (void)setupApp:(BOOL)useLocalBuild;
- (void)setupHandlers:(BOOL)useLocalBuild;
/* Webview API
 *************/
+ (void) notify:(NSString*)name info:(NSDictionary*)info;
+ (void) notify:(NSString*)name;
- (void) notify:(NSString*)name info:(NSDictionary*)info;
- (void) notify:(NSString*)name;

/* Keyboard
 **********/
- (void)putWindowOverKeyboard;
- (void)putWindowUnderKeyboard;

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
