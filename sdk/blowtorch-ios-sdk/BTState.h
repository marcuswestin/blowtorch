#import <Foundation/Foundation.h>

@interface BTState : NSObject

- (void) set:(NSString*)key value:(id)value;
- (id) get:(NSString*)key;
- (NSDictionary*) load;
- (void) reset;

- (NSString *)getFilePath;

@end
