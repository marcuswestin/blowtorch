//
//  BTCamera.m
//  dogo
//
//  Created by Marcus Westin on 2/21/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTCamera.h"
#import "BTFiles.h"
#import "UIImage+Resize.h"

@implementation BTCamera {
    UIImagePickerController* picker;
    BTResponseCallback captureCallback;
    NSDictionary* captureParams;
}

static BTCamera* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    [app handleCommand:@"BTCamera.show" handler:^(id data, BTResponseCallback responseCallback) {
        if (picker) { return; }
        picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        picker.showsCameraControls = NO;
        picker.delegate = self;
        picker.view.frame = [[data objectForKey:@"position"] makeRect];
        [app.webView.superview insertSubview:picker.view belowSubview:app.webView];
    }];
    
    [app handleCommand:@"BTCamera.hide" handler:^(id data, BTResponseCallback responseCallback) {
        [picker.view removeFromSuperview];
        picker = nil;
        responseCallback(nil, nil);
    }];
    
    [app handleCommand:@"BTCamera.capture" handler:^(id params, BTResponseCallback callback) {
        captureParams = params;
        captureCallback = callback;
        [picker takePicture];
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage* image = info[UIImagePickerControllerOriginalImage];
    
    if (captureParams[@"saveToAlbum"]) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    
    NSString* resize = captureParams[@"resize"];
    if (resize) {
        image = [image thumbnailSize:[resize makeSize] transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault];
    }
    
    NSData* data;
    if ([@"jpg" isEqualToString:captureParams[@"format"]]) {
        NSNumber* compressionQuality = captureParams[@"compressionQuality"];
        data = UIImageJPEGRepresentation(image, compressionQuality ? [compressionQuality floatValue] : 1.0);
    } else {
        data = UIImagePNGRepresentation(image);
    }
    NSString* file = [BTFiles documentPath:captureParams[@"document"]];
    BOOL success = [data writeToFile:file atomically:YES];
    if (!success) { return captureCallback(@"Could not store image", nil); }
    
    captureCallback(nil, @{ @"file":file });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [BTAppDelegate notify:@"BTCamera.imagePickerControllerDidCancel"];
}
@end
