//
//  BTTextInput.m
//  dogo
//
//  Created by Marcus Westin on 10/7/12.
//  Copyright (c) 2012 Flutterby Labs. All rights reserved.
//

#import "BTTextInput.h"
#import <QuartzCore/QuartzCore.h>
#import "BTAppDelegate.h"

@implementation BTTextInput {
    UITextView* _textInput;
    NSDictionary* _params;
    UIWebView* _webView;
}

static BTTextInput* instance;

- (void) setup:(BTAppDelegate*)app {
    if (instance) { return; }
    instance = self;

    _params = [NSDictionary dictionary];

    [app handleCommand:@"textInput.show" handler:^(id data, BTCallback responseCallback) {
        [self show:data webView:app.webView];
    }];
    [app handleCommand:@"textInput.hide" handler:^(id data,  BTCallback responseCallback) {
        [self hide];
    }];
    [app handleCommand:@"textInput.animate" handler:^(id data,  BTCallback responseCallback) {
        [self animate:data];
    }];
    [app handleCommand:@"textInput.set" handler:^(id data,  BTCallback responseCallback) {
        [self set:data];
    }];
    [app handleCommand:@"textInput.hideKeyboard" handler:^(id data, BTCallback responseCallback) {
        [self hideKeyboard];
    }];
    [app handleCommand:@"BTTextInput.setConfig" handler:^(id data, BTCallback responseCallback) {
        _params = data;
        responseCallback(nil,nil);
    }];
    [app handleCommand:@"BTTextInput.resetConfig" handler:^(id data, BTCallback responseCallback) {
        responseCallback(nil,nil);
    }];
    
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)hideKeyboard {
    [self blur:BTAppDelegate.instance.webView];
}

- (bool) blur:(UIView*)view {
    if ([view isFirstResponder]) {
        [view resignFirstResponder];
        return YES;
    }
    for (UIView* subview in [view subviews]) {
        if ([self blur:subview]) { return YES; }
    }
    return NO;
}

- (void) show:(NSDictionary*)params webView:(UIWebView*)webView {
    [self hide];
    
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
    _params = [NSDictionary dictionary];
    _webView = nil;
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
    [BTAppDelegate notify:@"textInput.didChange" info:[NSDictionary dictionaryWithObject:_textInput.text forKey:@"text"]];
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
        [BTAppDelegate notify:@"textInput.return" info:[NSDictionary dictionaryWithObject:_textInput.text forKey:@"text"]];
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
    [BTAppDelegate notify:@"textInput.didEndEditing" info:nil];
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
        [BTAppDelegate notify:@"textInput.changedHeight" info:info];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [BTAppDelegate.instance putWindowOverKeyboard];
    [self performSelector:@selector(_removeWebViewKeyboardBar) withObject:nil afterDelay:0];
    if ([_params[@"preventWebviewShift"] boolValue]) {
        // do nothing
    } else {
        float delay = 0.02f; // 0.04f;
        [self _shiftWebviewWithKeyboard:notification delay:delay speedup:delay];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if ([_params[@"preventWebviewShift"] boolValue]) {
        // do nothing
    } else {
        [self _shiftWebviewWithKeyboard:notification delay:0 speedup:0.05f];
    }
}

- (void)_removeWebViewKeyboardBar {
    UIWindow *keyboardWindow = nil;
    for (UIWindow *testWindow in [[UIApplication sharedApplication] windows]) {
        if (![[testWindow class] isEqual:[UIWindow class]]) {
            keyboardWindow = testWindow;
            break;
        }
    }
    if (!keyboardWindow) { return; }
    for (UIView *possibleFormView in [keyboardWindow subviews]) {
        if ([[possibleFormView description] rangeOfString:@"<UIPeripheralHostView:"].location != NSNotFound) {
            for (UIView *subviewWhichIsPossibleFormView in [possibleFormView subviews]) {
                if ([[subviewWhichIsPossibleFormView description] rangeOfString:@"<UIKeyboardAutomatic:"].location != NSNotFound) {
//                    UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 2)];
//                    view.backgroundColor = [UIColor colorWithRed:144/255.0 green:152/255.0 blue:163/255.0 alpha:1];
//                    [subviewWhichIsPossibleFormView addSubview:view];

                } else if ([[subviewWhichIsPossibleFormView description] rangeOfString:@"<UIImageView:"].location != NSNotFound) {
                    // ios6 on retina phone adds a drop shadow to the UIWebFormAccessory. Hide it.
                    subviewWhichIsPossibleFormView.frame = CGRectMake(0,0,0,0);
                } else if ([[subviewWhichIsPossibleFormView description] rangeOfString:@"UIWebFormAccessory"].location != NSNotFound) {
                    // This is the "prev/next/done" bar
                    [subviewWhichIsPossibleFormView removeFromSuperview];
                }
            }
        }
    }
    [BTAppDelegate.instance putWindowUnderKeyboard];
}

- (void)_shiftWebviewWithKeyboard:(NSNotification *)notification delay:(float)delay speedup:(double)speedup {
    NSDictionary* userInfo = [notification userInfo];
    NSTimeInterval animationDuration;
    CGRect begin;
    CGRect end;
    UIViewAnimationCurve animationCurve;
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] getValue:&begin];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&end];
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    float keyboardHeight = end.size.height;
    float target = end.origin.y;
    float newY = (target >= [[UIScreen mainScreen] bounds].size.height
                  ? -20 // keyboard showing (20 for status bar
                  : -(keyboardHeight - (44 - 20)) // keyboard showing (44 for webview keyboard accessory, 20 for status bar)
                  );
    UIWebView* webView = BTAppDelegate.instance.webView;
    CGRect frame = webView.frame;
    if (frame.origin.y == newY) { return; }
    CGRect newFrame = CGRectMake(frame.origin.x, newY, frame.size.width, frame.size.height);
    animationDuration -= speedup;
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState | animationOptionsWithCurve(animationCurve);
    [UIView animateWithDuration:animationDuration delay:delay options:options animations:^{ webView.frame = newFrame; } completion:nil];
}

static inline UIViewAnimationOptions animationOptionsWithCurve(UIViewAnimationCurve curve) {
    switch (curve) {
        case UIViewAnimationCurveEaseInOut:
            return UIViewAnimationOptionCurveEaseInOut;
        case UIViewAnimationCurveEaseIn:
            return UIViewAnimationOptionCurveEaseIn;
        case UIViewAnimationCurveEaseOut:
            return UIViewAnimationOptionCurveEaseOut;
        case UIViewAnimationCurveLinear:
            return UIViewAnimationOptionCurveLinear;
    }
}

@end
