//
//  BTAppDelegate.m
//  Dogo
//
//  Created by Marcus Westin on 6/13/13.
//  Copyright (c) 2013 Flutterby Labs Inc. All rights reserved.
//

#import "BTAppBase.h"
#import "BTModule.h"

@implementation BTAppBase {
    WebViewJavascriptBridge* _bridge;
    NSURL* _server;
    NSString* _mode;
}

static BTAppBase* instance;

/* API
 *****/
+ (void)notify:(NSString *)name info:(NSDictionary *)info {
    [instance _notify:name info:info];
}
+ (void)notify:(NSString *)name {
    [instance _notify:name info:NULL];
}
+ (void)handleCommand:(NSString *)handlerName handler:(BTCommandHandler)handler {
    [instance _handleCommand:handlerName handler:handler];
}
+ (void)handleRequests:(NSString *)path handler:(BTRequestHandler)requestHandler {
    [instance _handleRequests:path handler:requestHandler];
}
+ (void)reload {
    [instance _reload];
}
+ (BTAppBase*) instance { return instance; } // TODO Remove

+ (void)addSubview:(BT_VIEW_TYPE*)view {
    [instance _platformAddSubview:view];
}



/* Platform specifc internals
 ****************************/
- (void)_platformLoadWebView:(NSString *)url {
    [self _baseImpl:@"_platformLoadWebView"];
}
- (void)_platformAddSubview:(UIView *)view {
    [self _baseImpl:@"_platformLoadWebView"];
}



/* Platform agnostic internals
 *****************************/
- (void)_baseImpl:(NSString *)method {
    NSLog(@"You must implement %@", method);
    [NSException raise:@"NotImplemented" format:@"NotImplemented"];
}

- (void)_baseStartWithWebView:(BT_WEBVIEW_TYPE*)webview delegate:(BT_WEBVIEW_DELEGATE_TYPE*)delegate server:(NSString *)server mode:(NSString *)mode {
    instance = self;
    _server = [NSURL URLWithString:server];
    _mode = mode;
    
    _bridge = [WebViewJavascriptBridge bridgeForWebView:webview webViewDelegate:delegate handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"Warning: Received vanilla WVJB message %@", data);
        responseCallback(@{ @"error":@"Vanilla WVJB message" });
    }];
    
    [BTModule _setupAll];
    
    [self _setupHandlers];
    [self _reload];
}

- (void)_reload {
    NSString* appHtmlUrl = [_server.absoluteString stringByAppendingString:@"/resources/app.html"];
    [self _platformLoadWebView:appHtmlUrl];
    NSDictionary* config = @{
                             @"serverUrl":_server.absoluteString,
                             @"mode":_mode
                             };
    [self _notify:@"app.init" info:@{ @"config":config }];
}

- (void)_setupHandlers {
    [self _handleCommand:@"log" handler:^(id params, BTCallback callback) {
        NSString* jsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:params options:0 error:nil] encoding:NSUTF8StringEncoding];
        if (jsonString.length > 400) {
            jsonString = [[jsonString substringToIndex:400] stringByAppendingString:@" (...)"];
        }
        NSLog(@"Log: %@", jsonString);
        callback(nil,nil);
    }];
}

- (void)_notify:(NSString *)event info:(id)info {
    //    NSLog(@"Notify %@ %@", event, info);
    if (!info) { info = [NSDictionary dictionary]; }
    
    if ([info isKindOfClass:[NSError class]]) {
        info = [NSDictionary dictionaryWithObjectsAndKeys:[info localizedDescription], @"message", nil];
    }
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:event object:nil userInfo:info]];
    [_bridge send:[NSDictionary dictionaryWithObjectsAndKeys:event, @"event", info, @"info", nil]];
}

- (void)_handleCommand:(NSString *)handlerName handler:(BTCommandHandler)handler {
    [_bridge registerHandler:handlerName handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString* async = data ? data[@"async"] : nil;
        if (async) {
            dispatch_queue_t queue;
            if ([async isEqualToString:@"main"]) {
                queue = dispatch_get_main_queue();
            } else if ([async isEqualToString:@"high"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
            } else if ([async isEqualToString:@"low"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            } else if ([async isEqualToString:@"background"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
            } else {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            }
            dispatch_async(queue, ^{
                [self _doHandleCommand:handlerName handler:handler data:data responseCallback:responseCallback];
            });
        } else {
            [self _doHandleCommand:handlerName handler:handler data:data responseCallback:responseCallback];
        }
    }];
}

- (void)_doHandleCommand:(NSString*)handlerName handler:(BTCommandHandler)handler data:(NSDictionary*)data responseCallback:(WVJBResponseCallback)responseCallback {
    @try {
        handler(data, ^(id err, id responseData) {
            if (err) {
                if ([err isKindOfClass:[NSError class]]) {
                    err = @{ @"message":[err localizedDescription] };
                }
                responseCallback(@{ @"error":err });
            } else if (responseData) {
                responseCallback(@{ @"responseData":responseData });
            } else {
                responseCallback(@{});
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"WARNING: handleCommand:%@ threw with params:%@ error:%@", handlerName, data, exception);
        responseCallback(@{ @"error": @{ @"message":exception.name, @"reason":exception.reason }});
    }
}

- (void)_handleRequests:(NSString *)command handler:(BTRequestHandler)requestHandler {
    [WebViewProxy handleRequestsWithHost:_server.host path:command handler:^(NSURLRequest *req, WVPResponse *res) {
        NSDictionary* params = [req.URL.query parseQueryParams];
        requestHandler(params, res);
    }];
}

@end
