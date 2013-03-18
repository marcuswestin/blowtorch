#import "WebViewProxy.h"

typedef void (^BTResponseCallback)(id err, id responseData);
typedef void (^BTCommandHandler)(id params, BTResponseCallback callback);
typedef void (^BTRequestHandler)(NSDictionary* params, WVPResponse* response);