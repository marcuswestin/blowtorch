#import <UIKit/UIKit.h>
#import "BTModule.h"

@interface BTNet : BTModule

//- (void)cache:(NSString*)url override:(BOOL)override asUrl:(NSString*)asUrl responseCallback:(WVJBResponseCallback)responseCallback;

//+ (NSString *)urlEncodeValue:(NSString *)str;

+ (void)request:(NSDictionary*)data responseCallback:(BTCallback)responseCallback;

+ (void)post:(NSString*)url jsonParams:(NSDictionary*)jsonParams attachments:(NSDictionary*)attachments headers:(NSDictionary*)headers boundary:(NSString*)boundary responseCallback:(BTCallback)responseCallback;

+ (void)postMultipart:(NSString *)url headers:(NSDictionary *)headers parts:(NSArray *)parts boundary:(NSString*)boundary responseCallback:(BTCallback)responseCallback;

+ (void)request:(NSString*)url method:(NSString*)method headers:(NSDictionary*)headers params:(NSDictionary*)params responseCallback:(BTCallback)responseCallback;

@end
