#import "WebViewProxy.h"
#import "BTEnumeration.h"
#import "NSString+BTUtils.h"
#import "NSArray+BTUtils.h"

typedef void (^BTCallback)(id err, id responseData);
typedef void (^BTCommandHandler)(id params, BTCallback callback);
typedef void (^BTRequestHandler)(NSDictionary* params, WVPResponse* response);

#if defined __MAC_OS_X_VERSION_MAX_ALLOWED
    #define BT_PLATFORM_OSX
    #define BT_APPLICATION_DELEGATE_TYPE NSObject <NSApplicationDelegate>
    #define BT_WEBVIEW_TYPE WebView
    #define BT_WEBVIEW_DELEGATE_TYPE NSObject
    #define BT_VIEW_TYPE NSView
#elif defined __IPHONE_OS_VERSION_MAX_ALLOWED
    #define BT_PLATFORM_IOS
    #define BT_APPLICATION_DELEGATE_TYPE UIResponder <UIApplicationDelegate>
    #define BT_WEBVIEW_TYPE UIWebView
    #define BT_WEBVIEW_DELEGATE_TYPE NSObject <UIWebViewDelegate>
    #define BT_VIEW_TYPE UIView
#endif
