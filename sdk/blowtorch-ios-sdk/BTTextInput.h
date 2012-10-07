//
//  BTTextInput.h
//  dogo
//
//  Created by Marcus Westin on 10/7/12.
//  Copyright (c) 2012 Flutterby Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BTTextInput : NSObject
@property (strong,nonatomic,readonly) UITextView* textInput;
+ (void) show:(NSDictionary*)params webView:(UIWebView*)webView;
+ (void) hide;
+ (void) set:(NSDictionary*) params;
+ (void) animate:(NSDictionary*) params;
@end
