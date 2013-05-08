//
//  BTEnumeration.m
//  dogo
//
//  Created by Marcus Westin on 5/7/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTEnumeration.h"
#import "BTCamera.h"

@implementation BTEnumeration {
    int _default;
    NSString* _paramsName;
    NSMutableDictionary* _strToNum;
}

- (id)initWithParamsName:(NSString*)paramsName defaultEnumVal:(int)defaultEnumVal {
    if (self=[super init]) {
        _paramsName = paramsName;
        _default = defaultEnumVal;
        _strToNum = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (BTEnumeration *)enum:(NSString*)paramsName default:(int)defaultEnumVal string:(NSString *)stringVal {
    return [[[BTEnumeration alloc] initWithParamsName:paramsName defaultEnumVal:defaultEnumVal] add:defaultEnumVal string:stringVal];
}

- (BTEnumeration *)add:(int)enumVal string:(NSString *)stringVal {
    stringVal = [stringVal lowercaseString];
    if (_strToNum[stringVal]) {
        [NSException raise:@"BTEnumerationException" format:@"String value %@ added twice", stringVal];
    }
    _strToNum[stringVal] = [NSNumber numberWithInt:enumVal];
    return self;
}

- (int)from:(NSDictionary*)params {
    return [self _intFor:params[_paramsName]];
}

- (int)_intFor:(NSString*)strVal {
    if (!strVal) { return _default; }
    strVal = [strVal lowercaseString];
    return _strToNum[strVal] ? [_strToNum[strVal] intValue] : _default;
}

- (BOOL)value:(int)enumValue is:(NSString *)stringVal {
    return enumValue == [self _intFor:stringVal];
}

- (BOOL)from:(NSDictionary *)params is:(NSString *)stringVal {
    return [self from:params] == [self _intFor:stringVal];
}

@end
