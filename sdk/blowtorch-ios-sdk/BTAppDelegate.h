#import <UIKit/UIKit.h>
#import "JSONKit.h"
#import "WebViewJavascriptBridge.h"
#import "BTNet.h"
#import "BTState.h"
#import <AudioToolbox/AudioServices.h>

@interface BTAppDelegate : UIResponder <UIApplicationDelegate, UIWebViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate>

/* Properties
 ************/
@property (strong, atomic) NSString* serverHost;
@property (atomic, strong) BTState* state;
@property (atomic, strong) BTNet* net;
@property (strong, atomic) NSMutableDictionary* config;

/* Lifecycle API
 ***************/
- (void)startApp:(BOOL)devMode;
- (void)setAppInfo:(NSString*)key value:(NSString*)value;
- (NSString*)getAppInfo:(NSString*)key;

/* Webview API
 *************/
- (void) notify:(NSString*)name info:(NSDictionary*)response;
- (void) notify:(NSString*)name;
- (void) handleBridgeData:(id)data response:(WVJBResponse*)response;
- (void)setupBridgeHandlers;

/* Net API
 *********/
- (NSCachedURLResponse *) cachedResponseForRequest:(NSURLRequest *)request url:(NSURL*)url host:(NSString*)host path:(NSString*)path;
- (NSCachedURLResponse *) localFileResponse:(NSString*)filePath forUrl:(NSURL*)url;

/* Upgrade API
 *************/
- (void) downloadAppVersion:(NSDictionary*)data response:(WVJBResponse*)response;
- (NSString*) getCurrentVersion;

/* Keyboard
 **********/
- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;

/* Misc
 ******/
- (NSString*) unique;
- (BOOL) isRetina;
- (void) pickMedia:(NSDictionary*)data response:(WVJBResponse*)response;
@property (atomic,strong) NSMutableDictionary* mediaCache;
@property (atomic,strong) WVJBResponse* mediaResponse;
- (void) showMenu:(NSDictionary*)data response:(WVJBResponse*)response;
@property (atomic,strong) WVJBResponse* menuResponse;

/* Notifications
 ***************/
@property (nonatomic,copy) WVJBResponse* pushRegistrationResponse;
- (void) registerForPush:(WVJBResponse*)response;
@property (strong, nonatomic) NSDictionary* launchNotification;
- (void) handlePushNotification:(NSDictionary*)notification didBringAppToForeground:(BOOL)didBringAppToForeground;

/* Private
 *********/
- (NSDictionary*) keyboardEventInfo:(NSNotification*) notification;
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;
@property (strong, atomic) UIView* overlay;

@end


@interface BTInterceptionCache : NSURLCache
@property (strong, atomic) BTAppDelegate* blowtorchInstance;
@end
