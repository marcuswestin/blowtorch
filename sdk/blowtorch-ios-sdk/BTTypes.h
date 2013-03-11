#import "WebViewProxy.h"

typedef void (^BTResponseCallback)(id error, id responseData);
typedef void (^BTCommandHandler)(id data, BTResponseCallback callback);
typedef void (^BTRequestHandler)(NSDictionary* params, WVPResponse* response);