#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge.h"
#import "BTResponse.h"

@interface BTNet : NSObject

//- (void)cache:(NSString*)url override:(BOOL)override asUrl:(NSString*)asUrl responseCallback:(WVJBResponseCallback)responseCallback;

//+ (NSString *)urlEncodeValue:(NSString *)str;

+ (void)request:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback;

+ (void)post:url json:params data:audioData headers:headers boundary:boundary responseCallback:responseCallback;

+ (void)postMultipart:(NSString *)url headers:(NSDictionary *)headers parts:(NSArray *)parts boundary:(NSString*)boundary responseCallback:(BTResponseCallback)responseCallback;

+ (void)request:(NSString*)url method:(NSString*)method headers:(NSDictionary*)headers params:(NSDictionary*)params responseCallback:(BTResponseCallback)responseCallback;

@end
