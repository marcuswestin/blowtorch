//
//  BTApp_OSX.m
//  Dogo
//
//  Created by Marcus Westin on 6/13/13.
//  Copyright (c) 2013 Flutterby Labs Inc. All rights reserved.
//

#import "BTApp.h"
#import <WebKit/WebKit.h>

@implementation BTApp {
    WebView* _webView;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSView* contentView = self.window.contentView;
    _webView = [[WebView alloc] initWithFrame:contentView.frame];
    [_webView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
    [contentView addSubview:_webView];
    
    [self _baseStartWithWebView:_webView delegate:self server:@"https://dogo.co"];
    
    [BTApp handleCommand:@"BTNotifications.setBadgeNumber" handler:^(id params, BTCallback callback) {
        callback(nil,nil);
    }];
}

- (void)_platformLoadWebView:(NSString*)url {
    _webView.mainFrameURL = url;
}

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:message];
    [alert runModal];
}

@end
