#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge.h"
#import "BTResponse.h"

@interface BTNet : NSObject

//- (void)cache:(NSString*)url override:(BOOL)override asUrl:(NSString*)asUrl responseCallback:(WVJBResponseCallback)responseCallback;

//+ (NSString *)urlEncodeValue:(NSString *)str;

+ (void)request:(NSString*)url method:(NSString*)method headers:(NSDictionary*)headers params:(NSDictionary*)params responseCallback:(BTResponseCallback)responseCallback;

@end
