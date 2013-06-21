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
- (void)_platformAddSubview:(BT_WEBVIEW_TYPE*)view {
    [self _baseImpl:@"_platformLoadWebView"];
}


/* platform agnostic events
 **************************/

/* Remote notifications
 **********************/
- (void)application:(BT(Application) *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didRegisterForRemoteNotifications" object:nil userInfo:@{ @"deviceToken":deviceToken }];
}

- (void)application:(BT(Application) *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didFailToRegisterForRemoteNotifications" object:nil userInfo:nil];
}

- (void)application:(BT(Application) *)application didReceiveRemoteNotification:(NSDictionary *)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"application.didReceiveRemoteNotification" object:nil userInfo:@{ @"notification":notification }];
}


/* Platform agnostic internals
 *****************************/
- (void)_baseImpl:(NSString *)method {
    NSLog(@"You must implement %@", method);
    [NSException raise:@"NotImplemented" format:@"NotImplemented"];
}

- (NSString*) mode { return _mode; }

- (void)_baseStartWithWebView:(BT_WEBVIEW_TYPE*)webview delegate:(BT_WEBVIEW_DELEGATE_TYPE*)delegate server:(NSString *)server {
    instance = self;

#if defined TESTFLIGHT
    _mode = @"TESTFLIGHT";
    _server = [NSURL URLWithString:server];
#elif defined DEBUG
    _mode = @"DEBUG";
    NSString* devHostFile = [[NSBundle mainBundle] pathForResource:@"dev-hostname" ofType:@"txt"];
    NSString* host = [[NSString stringWithContentsOfFile:devHostFile encoding:NSUTF8StringEncoding error:nil] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    _server = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:9000", host]];
#else
    _mode = @"DISTRIBUTION";
    _server = [NSURL URLWithString:server];
#endif

    _bridge = [WebViewJavascriptBridge bridgeForWebView:webview webViewDelegate:delegate handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"Warning: Received vanilla WVJB message %@", data);
        responseCallback(@{ @"error":@"Vanilla WVJB message" });
    }];
    
    [BTModule _setupAll];
    
    [self _setupHandlers];
    [self _reload];
}

- (void)_reload {
    [_bridge reset];
    NSString* appHtmlUrl = [_server.absoluteString stringByAppendingString:@"/resources/app.html"];
    [self _platformLoadWebView:appHtmlUrl];

    NSDictionary* config = @{
                             @"serverUrl":_server.absoluteString,
                             @"mode":_mode,
                             @"locale":[[NSLocale currentLocale ] localeIdentifier]
//                             @"device": @{
//                                     @"systemVersion":[[UIDevice currentDevice] systemVersion],
//                                     @"model":[UIDevice currentDevice].model,
//                                     @"name":[UIDevice currentDevice].name,
//                                     }
                             };
    [self _notify:@"app.init" info:@{ @"config":config }];
}

- (void)_setupHandlers {
    [self _handleCommand:@"log" handler:^(id params, BTCallback callback) {
        [self _log:params callback:callback];
    }];

    [self _handleCommand:@"app.reload" handler:^(id params, BTCallback callback) {
        [self _reload];
    }];
    
    if (![_mode isEqualToString:@"DEBUG"]) {
        resourceDir = [[NSBundle mainBundle] pathForResource:@"dogo-client-build" ofType:nil];
        [WebViewProxy handleRequestsWithHost:_server.host pathPrefix:@"/resources/" handler:^(NSURLRequest *req, WVPResponse *res) {
            [self _serveResource:req res:res];
        }];
    }
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


/* Command & Request Handlers
 ****************************/
- (void)_log:(NSDictionary*)params callback:(BTCallback)callback {
    NSString* jsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:params options:0 error:nil] encoding:NSUTF8StringEncoding];
    if (jsonString.length > 400) {
        jsonString = [[jsonString substringToIndex:400] stringByAppendingString:@" (...)"];
    }
    NSLog(@"Log: %@", jsonString);
    callback(nil,nil);
}

static NSString* resourceDir;
- (void) _serveResource:(NSURLRequest*)req res:(WVPResponse*)res {
    NSString* resource = req.URL.path;
    NSString* path = [resourceDir stringByAppendingPathComponent:resource];
    NSData* data = [NSData dataWithContentsOfFile:path];
    [res respondWithData:data mimeType:nil];
}

@end
