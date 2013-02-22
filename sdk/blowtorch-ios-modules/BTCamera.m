//
//  BTCamera.m
//  dogo
//
//  Created by Marcus Westin on 2/21/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTCamera.h"

@implementation BTCamera

static BTCamera* instance;
static UIImagePickerController* picker;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    [app registerHandler:@"BTCamera.show" handler:^(id data, BTResponseCallback responseCallback) {
        if (picker) { return; }
        picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        picker.showsCameraControls = NO;
        picker.view.frame = [[data objectForKey:@"position"] makeRect];
        [app.webView.superview insertSubview:picker.view belowSubview:app.webView];
    }];
    
    [app registerHandler:@"BTCamera.hide" handler:^(id data, BTResponseCallback responseCallback) {
        [picker.view removeFromSuperview];
        picker = nil;
        responseCallback(nil, nil);
    }];
}

@end
