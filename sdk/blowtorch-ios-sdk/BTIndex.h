#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge.h"

@interface BTIndexByStrings : NSObject

@property (nonatomic,strong) id payload;
@property (nonatomic,strong) NSArray* strings;

@end

@interface BTIndex : NSObject

@property (atomic, strong) NSDictionary* listsByFirstCharacter;

+ (void) buildIndex:(NSString*)name payloadToStrings:(NSDictionary*)payloadToStrings;
+ (BTIndex*) indexByName:(NSString*)name;
- (void) lookup:(NSString*)string response:(WVJBResponse*)response;
- (void) respond:(NSSet*)matches response:(WVJBResponse*)response;

@end
