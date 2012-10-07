#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge.h"

@interface BTNet : NSObject

@property (nonatomic,strong) MKNetworkEngine* engine;

- (void)cache:(NSString*)url override:(BOOL)override asUrl:(NSString*)asUrl responseCallback:(WVJBResponseCallback)responseCallback;

+ (NSString *)urlEncodeValue:(NSString *)str;

+ (NSString*)pathForUrl:(NSString*)url;

+ (void)request:(NSString*)url method:(NSString*)method headers:(NSDictionary*)headers params:(NSDictionary*)params responseCallback:(WVJBResponseCallback)responseCallback;

@end
