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
    BTCallback captureCallback;
    NSDictionary* captureParams;
}

static BTCamera* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    [app handleCommand:@"BTCamera.show" handler:^(id params, BTCallback callback) {
        picker = [self _createPicker:params];
        picker.view.frame = [[params objectForKey:@"position"] makeRect];
        if (params[@"modal"]) {
            [app.window.rootViewController presentViewController:picker animated:YES completion:NULL];
            captureParams = params;
            captureCallback = callback;
        } else {
            [app.webView.superview insertSubview:picker.view belowSubview:app.webView];
            callback(nil,nil);
        }
    }];
    
    [app handleCommand:@"BTCamera.hide" handler:^(id data, BTCallback responseCallback) {
        if (!picker) { return; }
        [picker.view removeFromSuperview];
        picker = nil;
        responseCallback(nil, nil);
    }];

    [app handleCommand:@"BTCamera.capture" handler:^(id params, BTCallback callback) {
        captureParams = params;
        captureCallback = callback;
        [picker takePicture];
    }];
}

- (UIImagePickerController*)_createPicker:(NSDictionary*)data {
    if (picker) {
        [picker.view removeFromSuperview];
    }
    picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.showsCameraControls = !data[@"hideControls"];
    picker.allowsEditing = !!data[@"allowEditing"];
    if (!!data[@"frontFacing"] && [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront]) {
        picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    }
    picker.delegate = self;
    return picker;
}

- (void)imagePickerController:(UIImagePickerController *)thePicker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    if (captureParams[@"saveToAlbum"]) {
        UIImageWriteToSavedPhotosAlbum(info[UIImagePickerControllerOriginalImage], nil, nil, nil);
    }
    
    UIImage* image = captureParams[@"allowEditing"] ? info[UIImagePickerControllerEditedImage] : info[UIImagePickerControllerOriginalImage];

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
    
    NSDictionary* response = @{ @"file":file, @"width":[NSNumber numberWithFloat:image.size.width], @"height":[NSNumber numberWithFloat:image.size.height] };
    if (captureParams[@"modal"]) {
        [BTAppDelegate.instance.window.rootViewController dismissViewControllerAnimated:YES completion:^{
            captureCallback(nil, response);
            picker = nil;
        }];
    } else {
        captureCallback(nil, response);
        picker = nil;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)thePicker {
    if (captureParams && captureParams[@"modal"]) {
        [BTAppDelegate.instance.window.rootViewController dismissViewControllerAnimated:YES completion:NULL];
    }
    [BTAppDelegate notify:@"BTCamera.imagePickerControllerDidCancel"];
    picker = nil;
}
@end
