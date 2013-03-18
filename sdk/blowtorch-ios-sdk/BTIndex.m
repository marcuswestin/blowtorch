#import "BTIndex.h"

static NSMutableDictionary* indices;

@implementation BTIndex

@synthesize listsByFirstCharacter;

+ (void) buildIndex:(NSString*)name payloadToStrings:(NSDictionary*)payloadToStrings {
    NSMutableDictionary* listsByFirstCharacter = [NSMutableDictionary dictionary];
    for (id payload in payloadToStrings) {
        NSArray* strings = [payloadToStrings objectForKey:payload];
        BTIndexByStrings* indexByStrings = [[BTIndexByStrings alloc] init];
        indexByStrings.payload = payload;
        indexByStrings.strings = strings;
        for (NSString* string in strings) {
            NSString* indexFirstChar = [[string substringToIndex:1] lowercaseString];
            if (![listsByFirstCharacter objectForKey:indexFirstChar]) {
                [listsByFirstCharacter setObject:[NSMutableArray array] forKey:indexFirstChar];
            }
            [[listsByFirstCharacter objectForKey:indexFirstChar] addObject:indexByStrings];
        }
    }

    BTIndex* index = [[BTIndex alloc] init];
    index.listsByFirstCharacter = listsByFirstCharacter;
    
    if (!indices) { indices = [NSMutableDictionary dictionary]; }
    [indices setObject:index forKey:name];
}

+ (BTIndex *)indexByName:(NSString *)name {
    if (!indices) { return nil; }
    return [indices objectForKey:name];
}

- (void)lookup:(NSString *)searchString callback:(BTCallback)callback {
    NSMutableSet* matches = [NSMutableSet set];
    if (!listsByFirstCharacter || !searchString || [searchString isEqualToString:@""]) {
        return [self respond:matches callback:callback];
    }
    NSString* indexFirstChar = [[searchString substringToIndex:1] lowercaseString];
    NSArray* possibleMatches = [listsByFirstCharacter objectForKey:indexFirstChar];
    if (!possibleMatches) {
        return [self respond:matches callback:callback];
    }
    NSPredicate* beginsWithsearchString = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] %@", searchString];
    for (BTIndexByStrings* indexByStrings in possibleMatches) {
        for (NSString* string in indexByStrings.strings) {
            if ([beginsWithsearchString evaluateWithObject:string]) {
                [matches addObject:indexByStrings.payload];
                break;
            }
        }
    }
    [self respond:matches callback:callback];
}

- (void)respond:(NSSet *)matches callback:(BTCallback)callback {
    callback(nil, @{ @"matches":matches });
}

@end

@implementation BTIndexByStrings 
@synthesize payload, strings;
@end
