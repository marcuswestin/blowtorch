//
//  BTResponse.h
//  dogo
//
//  Created by Marcus Westin on 12/10/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebViewJavascriptBridge.h"

typedef void (^BTResponseCallback)(id error, id responseData);
typedef void (^BTHandler)(id data, BTResponseCallback responseCallback);

@interface BTResponse : NSObject
+ (BTResponse*) responseWithCallback:(BTResponseCallback)responseCallback;
- (BTResponse*) initWithResponseCallback:(BTResponseCallback)responseCallback;
- (void) respondWith:(id)responseData;
- (void) respondWithError:(id)error;
@end
