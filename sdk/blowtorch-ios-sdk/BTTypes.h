#import "WebViewProxy.h"

typedef void (^BTCallback)(id err, id responseData);
typedef void (^BTCommandHandler)(id params, BTCallback callback);
typedef void (^BTRequestHandler)(NSDictionary* params, WVPResponse* response);