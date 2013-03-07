#import <UIKit/UIKit.h>
#import "WebViewJavascriptBridge.h"
#import "BTModule.h"

@interface BTIndexByStrings : NSObject

@property (nonatomic,strong) id payload;
@property (nonatomic,strong) NSArray* strings;

@end

@interface BTIndex : NSObject

@property (atomic, strong) NSDictionary* listsByFirstCharacter;

+ (void) buildIndex:(NSString*)name payloadToStrings:(NSDictionary*)payloadToStrings;
+ (BTIndex*) indexByName:(NSString*)name;
- (void) lookup:(NSString*)string callback:(BTResponseCallback)callback;
- (void) respond:(NSSet*)matches callback:(BTResponseCallback)callback;

@end
