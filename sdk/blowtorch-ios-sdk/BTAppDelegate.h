#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge.h"
#import "WebViewProxy.h"
#import "BTNet.h"
#import "BTState.h"
#import <AudioToolbox/AudioServices.h>
#import "BTCache.h"
#import "BTResponse.h"

#import "NSString+Util.h"

@interface BTAppDelegate : UIResponder <UIApplicationDelegate, UIWebViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate>

+ (BTAppDelegate*) instance;

/* Properties
 ************/
@property (atomic, strong) BTState* state;
@property (atomic, strong) BTNet* net;
@property (strong, atomic) NSMutableDictionary* config;
@property (strong, nonatomic) BTCache* cache;
@property (strong, nonatomic) BTCache* documents;

- (NSString*) serverUrl;
- (NSString*) serverHost;
- (void) setServerScheme:(NSString*)scheme host:(NSString*)host port:(NSString*)port;

/* Lifecycle API
 ***************/
- (void)setupModules;
- (void)setupApp:(BOOL)devMode;
- (void)startApp;
- (void)setAppInfo:(NSString*)key value:(NSString*)value;
- (NSString*)getAppInfo:(NSString*)key;

/* Webview API
 *************/
- (void) notify:(NSString*)name info:(NSDictionary*)response;
- (void) notify:(NSString*)name;
- (void) setupBridgeHandlers;
- (void) setupNetHandlers;

/* Upgrade API
 *************/
- (void) downloadAppVersion:(NSDictionary*)data response:(BTResponse*)response;
- (NSString*) getCurrentVersion;

/* Keyboard
 **********/
- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;

/* Misc
 ******/
- (NSString*) unique;
- (BOOL) isRetina;
- (void) pickMedia:(NSDictionary*)data response:(BTResponse*)response;
@property (atomic,strong) NSMutableDictionary* mediaCache;
@property (atomic,strong) BTResponse* mediaResponse;
- (void) showMenu:(NSDictionary*)data response:(BTResponse*)response;
@property (atomic,strong) BTResponse* menuResponse;

/* Notifications
 ***************/
@property (nonatomic,copy) BTResponseCallback pushRegistrationResponseCallback;
- (void) registerForPush:(BTResponseCallback)response;
@property (strong, nonatomic) NSDictionary* launchNotification;
- (void) handlePushNotification:(NSDictionary*)notification didBringAppToForeground:(BOOL)didBringAppToForeground;

/* Private
 *********/
- (void) registerHandler:(NSString*)handlerName handler:(BTHandler)handler;
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;
@property (strong, atomic) UIView* overlay;

@end


@interface BTInterceptionCache : NSURLCache
@property (strong, atomic) BTAppDelegate* blowtorchInstance;
@end
