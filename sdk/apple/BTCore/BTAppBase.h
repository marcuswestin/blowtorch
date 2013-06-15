//
//  BTAppDelegate.h
//  Dogo
//
//  Created by Marcus Westin on 6/13/13.
//  Copyright (c) 2013 Flutterby Labs Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTTypes.h"
#import "WebViewJavascriptBridge.h"

@interface BTAppBase : BT_APPLICATION_DELEGATE_TYPE

+ (void) handleRequests:(NSString*)path handler:(BTRequestHandler)requestHandler;
+ (void) handleCommand:(NSString*)handlerName handler:(BTCommandHandler)handler;

+ (void) notify:(NSString*)name info:(NSDictionary*)info;
+ (void) notify:(NSString*)name;

+ (BT_APPLICATION_DELEGATE_TYPE*) instance;
+ (void) reload;

+ (void) addSubview:(BT_VIEW_TYPE*)view;

/* Platform specific internals
 *****************************/
- (void) _platformLoadWebView:(NSString*)url;
- (void) _platformAddSubview:(BT_VIEW_TYPE*)view;
/* Platform agnostic internals
 *****************************/
- (void) _baseStartWithWebView:(BT_WEBVIEW_TYPE*)webview delegate:(BT_WEBVIEW_DELEGATE_TYPE*)delegate server:(NSString*)server mode:(NSString*)mode;
- (void) _baseImpl:(NSString*)method;

@end
