#import "BTState.h"

@implementation BTState

- (NSDictionary *)load:(NSString *)key {
    NSData* jsonData = [NSData dataWithContentsOfFile:[self getFilePath:key]];
    NSDictionary* state = jsonData
        ? [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil]
        : [NSDictionary dictionary];
    return state;
}

- (void)set:(NSString *)key value:(NSDictionary*)value {
    NSString* path = [self getFilePath:key];
    if (value) {
        NSJSONWritingOptions opts = 0; // NSJSONWritingPrettyPrinted
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:value options:opts error:nil];
        [jsonData writeToFile:path atomically:YES];
    } else {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            NSError *error;
            [fileManager removeItemAtPath:path error:&error];
            if (error) {
                NSLog(@"Error removing state for key %@: %@", key, error);
            }
        }
    }
}

- (void)reset {
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [searchPaths lastObject];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray* contents = [fileManager contentsOfDirectoryAtPath:documentPath error:nil];
    NSArray* btstateFiles = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH .btstate"]];
    for (NSString* btstateFile in btstateFiles) {
        [fileManager removeItemAtPath:btstateFile error:nil];
    }
}

- (NSString *)getFilePath:(NSString *)key {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths lastObject];
    return [documentsDirectory stringByAppendingPathComponent:[key stringByAppendingString:@".btstate"]];
}

@end
