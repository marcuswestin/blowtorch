//
//  BTSplashScreen.m
//  dogo
//
//  Created by Marcus Westin on 6/14/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTSplashScreen.h"

@implementation BTSplashScreen {
    UIView* _splashScreen;
}

- (void)setup {
    [BTApp handleCommand:@"BTSplashScreen.hide" handler:^(id params, BTCallback callback) {
        [self _hide:params callback:callback];
    }];
    [self _show];
}

- (void)_show {
    if (_splashScreen) { return; }
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    UIImageView* splashScreen = [[UIImageView alloc] initWithFrame:screenBounds];
    _splashScreen = splashScreen;
    
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if (screenSize.height > 480.0f) {
            splashScreen.image = [UIImage imageNamed:@"Default-568h"];
        } else {
            splashScreen.image = [UIImage imageNamed:@"Default"];
        }
    } else {
        // TODO iPad
        splashScreen.image = [UIImage imageNamed:@"Default"];
    }
    
    NSNumber* fade = nil;
    if (fade) {
        splashScreen.alpha = 0.0;
        [BTApp addSubview:splashScreen];
        [UIView animateWithDuration:[fade doubleValue] animations:^{
            splashScreen.alpha = 1.0;
        } completion:^(BOOL finished) {
//            callback(nil,nil);
        }];
    } else {
        [BTApp addSubview:splashScreen];
//        callback(nil,nil);
    }
}

- (void)_hide:(NSDictionary *)params callback:(BTCallback)callback {
    if (!_splashScreen) { return; }
    UIView* hideOverlay = _splashScreen;
    _splashScreen = nil;
    [UIView animateWithDuration:[params[@"fade"] doubleValue] animations:^{
        hideOverlay.alpha = 0;
    } completion:^(BOOL finished) {
        [hideOverlay removeFromSuperview];
        callback(nil,nil);
    }];
}

@end
