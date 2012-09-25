#import <Foundation/Foundation.h>

@interface BTState : NSObject

- (void) set:(NSString*)key value:(id)value;
- (NSDictionary*) load:(NSString*)key;
- (NSString *)getFilePath:(NSString*)key;
- (void) reset;


@end
