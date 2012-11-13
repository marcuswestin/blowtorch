//
//  BTTextInput.m
//  dogo
//
//  Created by Marcus Westin on 10/7/12.
//  Copyright (c) 2012 Flutterby Labs. All rights reserved.
//

#import "BTTextInput.h"
#import <QuartzCore/QuartzCore.h>

@interface BTTextInput (hidden) <UITextViewDelegate>
- (void) show:(NSDictionary*)params webView:(UIWebView*)webView;
- (void) hide;
- (void) set:(NSDictionary*) params;
- (void) animate:(NSDictionary*) params;
- (void) size;
- (CGRect)rectFromDict:(NSDictionary *)params;
- (UIReturnKeyType)returnKeyTypeFromDict:(NSDictionary *)params;
- (UIEdgeInsets)insetsFromParam:(NSArray *)param;
- (UIColor *)colorFromParam:(NSArray *)param;
- (void)notify:(NSString*)signal info:(NSDictionary*)info;
@end

@implementation BTTextInput {
    UITextView* _textInput;
    NSDictionary* _params;
    UIWebView* _webView;
}

- (void) setup:(BTAppDelegate*)app {
    [app.javascriptBridge registerHandler:@"textInput.show" handler:^(id data, WVJBResponse* response) {
        [self show:data webView:app.webView];
    }];
    [app.javascriptBridge registerHandler:@"textInput.hide" handler:^(id data, WVJBResponse* response) {
        [self hide];
    }];
    [app.javascriptBridge registerHandler:@"textInput.animate" handler:^(id data, WVJBResponse* response) {
        [self animate:data];
    }];
    [app.javascriptBridge registerHandler:@"textInput.set" handler:^(id data, WVJBResponse* response) {
        [self set:data];
    }];
}

@end

@implementation BTTextInput (hidden)

- (void) show:(NSDictionary*)params webView:(UIWebView*)webView {
    [self hide];
    
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    _textInput = [[UITextView alloc] initWithFrame:[self rectFromDict:[params objectForKey:@"at"]]];
    _params=params;
    _webView = webView;
    
    _textInput.font = [UIFont systemFontOfSize:17];
    _textInput.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _textInput.clipsToBounds = YES;
    _textInput.scrollEnabled = NO;
    _textInput.keyboardType = UIKeyboardTypeDefault;
    _textInput.delegate = self;
    
    UIReturnKeyType returnKeyType = [self returnKeyTypeFromDict:params];
    if (returnKeyType) {
        _textInput.returnKeyType = returnKeyType;
    }
    
    NSDictionary* font = [params objectForKey:@"font"];
    if (font) {
        NSNumber* size = [font objectForKey:@"size"];
        [_textInput setFont:[UIFont fontWithName:[font objectForKey:@"name"] size:[size floatValue]]];
    }
    
    NSString* backgroundImage = [params objectForKey:@"backgroundImage"];
    if (backgroundImage) {
        _textInput.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:backgroundImage]];
    }
    if ([params objectForKey:@"backgroundColor"]) {
        _textInput.backgroundColor = [self colorFromParam:[params objectForKey:@"backgroundColor"]];
    }
    if ([params objectForKey:@"borderColor"]) {
        _textInput.layer.borderColor = [[self colorFromParam:[params objectForKey:@"borderColor"]] CGColor];
        _textInput.layer.borderWidth = 1.0;
    }
    if ([params objectForKey:@"cornerRadius"]) {
        NSNumber* cornerRadius = [params objectForKey:@"cornerRadius"];
        [_textInput.layer setCornerRadius:[cornerRadius floatValue]];
    }
    if ([params objectForKey:@"contentInset"]) {
        _textInput.contentInset = [self insetsFromParam:[params objectForKey:@"contentInset"]];
    }
    _textInput.text = @"";
    
    [_webView addSubview:_textInput];
    [_textInput becomeFirstResponder];
    
    [self size];
}

- (void) hide {
    if (!_textInput) { return; }
    [_textInput resignFirstResponder];
    [_textInput removeFromSuperview];
    _textInput = nil;
    _params = nil;
    _webView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) set:(NSDictionary*) params {
    _textInput.text = [params objectForKey:@"text"];
    [self size];
}

- (void)animate:(NSDictionary *)params {
    NSNumber* duration = [params objectForKey:@"duration"];
    [UIView animateWithDuration:[duration doubleValue] animations:^{
        _textInput.frame = [self rectFromDict:[params objectForKey:@"to"]];
        [self size];
    }];
    if ([params objectForKey:@"blur"]) {
        [_textInput resignFirstResponder];
    }
}

// Text view events
- (void)textViewDidChange:(UITextView *)textView {
    [self size];
    [self notify:@"textInput.didChange" info:[NSDictionary dictionaryWithObject:_textInput.text forKey:@"text"]];
}

- (UIReturnKeyType)returnKeyTypeFromDict:(NSDictionary *)params {
    NSString* returnKeyType = [params objectForKey:@"returnKeyType"];
    if ([returnKeyType isEqualToString:@"Done"]) { return UIReturnKeyDone; }
    if ([returnKeyType isEqualToString:@"EmergencyCall"]) { return UIReturnKeyEmergencyCall; }
    if ([returnKeyType isEqualToString:@"Go"]) { return UIReturnKeyGo; }
    if ([returnKeyType isEqualToString:@"Google"]) { return UIReturnKeyGoogle; }
    if ([returnKeyType isEqualToString:@"Join"]) { return UIReturnKeyJoin; }
    if ([returnKeyType isEqualToString:@"Next"]) { return UIReturnKeyNext; }
    if ([returnKeyType isEqualToString:@"Route"]) { return UIReturnKeyRoute; }
    if ([returnKeyType isEqualToString:@"Search"]) { return UIReturnKeySearch; }
    if ([returnKeyType isEqualToString:@"Send"]) { return UIReturnKeySend; }
    return UIReturnKeyDefault;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if([text isEqualToString:@"\n"]) {
        [self notify:@"textInput.return" info:[NSDictionary dictionaryWithObject:_textInput.text forKey:@"text"]];
        return NO;
    }
    return YES;
}

// Utilities
- (CGRect)rectFromDict:(NSDictionary *)params {
    CGRect frame;
    if (_textInput) {
        frame = _textInput.frame;
    } else {
        frame = CGRectMake(0, 0, 0, 0);
    }
    if ([params objectForKey:@"x"]) {
        frame.origin.x = [[params objectForKey:@"x"] doubleValue];
    }
    if ([params objectForKey:@"y"]) {
        frame.origin.y = [[params objectForKey:@"y"] doubleValue];
    }
    if ([params objectForKey:@"width"]) {
        frame.size.width = [[params objectForKey:@"width"] doubleValue];
    }
    if ([params objectForKey:@"height"]) {
        frame.size.height = [[params objectForKey:@"height"] doubleValue];
    }
    return frame;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    [self notify:@"textInput.didEndEditing" info:nil];
}

- (UIEdgeInsets)insetsFromParam:(NSArray *)param {
    NSNumber* n1 = [param objectAtIndex:0];
    NSNumber* n2 = [param objectAtIndex:1];
    NSNumber* n3 = [param objectAtIndex:2];
    NSNumber* n4 = [param objectAtIndex:3];
    return UIEdgeInsetsMake([n1 floatValue], [n2 floatValue], [n3 floatValue], [n4 floatValue]);
}

- (UIColor *)colorFromParam:(NSArray *)param {
    NSNumber* red = [param objectAtIndex:0];
    NSNumber* green = [param objectAtIndex:1];
    NSNumber* blue = [param objectAtIndex:2];
    NSNumber* alpha = [param objectAtIndex:3];
    return [UIColor colorWithRed:[red floatValue] green:[green floatValue] blue:[blue floatValue] alpha:[alpha floatValue]];
}

- (void)size {
    CGRect frame = _textInput.frame;
    frame.size.height = _textInput.contentSize.height;
    int dHeight = frame.size.height - _textInput.frame.size.height;
    if (dHeight != 0) {
        frame.origin.y -= dHeight;
        _textInput.frame = frame;
        NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt:dHeight], @"heightChange",
                              [NSNumber numberWithFloat:_textInput.frame.size.height], @"height",
                              nil];
        [self notify:@"textInput.changedHeight" info:info];
    }
}

- (void)notify:(NSString *)signal info:(NSDictionary *)info {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"bt.notify" object:signal userInfo:info];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if ([_params objectForKey:@"shiftWebview"]) {
        [self shiftWebviewWithKeyboard:notification];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if ([_params objectForKey:@"shiftWebview"]) {
        [self shiftWebviewWithKeyboard:notification];
    }
}

- (void)shiftWebviewWithKeyboard:(NSNotification *)notification {
    NSDictionary* userInfo = [notification userInfo];
    NSTimeInterval animationDuration;
    CGRect begin;
    CGRect end;
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] getValue:&begin];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&end];
    [UIView animateWithDuration:animationDuration animations:^{
        CGRect frame = _webView.frame;
        _webView.frame = CGRectMake(frame.origin.x, frame.origin.y-(begin.origin.y-end.origin.y), frame.size.width, frame.size.height);
    }];
}


@end
