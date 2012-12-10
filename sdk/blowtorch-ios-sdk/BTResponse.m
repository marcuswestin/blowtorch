//
//  BTResponse.m
//  dogo
//
//  Created by Marcus Westin on 12/10/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import "BTResponse.h"

@implementation BTResponse {
    BTResponseCallback _responseCallback;
}

+ (BTResponse *)responseWithCallback:(BTResponseCallback)responseCallback {
    return [[BTResponse alloc] initWithResponseCallback:responseCallback];
}

- (BTResponse *)initWithResponseCallback:(BTResponseCallback)responseCallback {
    if (self = [self init]) {
        _responseCallback = responseCallback;
    }
    return self;
}

- (void)respondWith:(id)payload {
    _responseCallback(nil, payload);
}

- (void)respondWithError:(id)error {
    _responseCallback(error, nil);
}

@end
