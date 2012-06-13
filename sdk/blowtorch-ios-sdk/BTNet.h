#import <UIKit/UIKit.h>
#import "BTTypes.h"

@interface BTNet : NSObject

@property (nonatomic,strong) MKNetworkEngine* engine;

- (void)cache:(NSString*)url override:(BOOL)override asUrl:(NSString*)asUrl responseCallback:(ResponseCallback)responseCallback;

+ (NSString *)urlEncodeValue:(NSString *)str;

+ (NSString*)pathForUrl:(NSString*)url;

@end
