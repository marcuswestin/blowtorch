#import <UIKit/UIKit.h>
#import "BTModule.h"

@interface BTIndexByStrings : NSObject

@property (nonatomic,strong) id payload;
@property (nonatomic,strong) NSArray* strings;

@end

@interface BTIndex : NSObject

@property (atomic, strong) NSDictionary* listsByFirstCharacter;

+ (void) buildIndex:(NSString*)name payloadToStrings:(NSDictionary*)payloadToStrings;
+ (BTIndex*) indexByName:(NSString*)name;
- (void) lookup:(NSString*)string callback:(BTCallback)callback;
- (void) respond:(NSSet*)matches callback:(BTCallback)callback;

@end
