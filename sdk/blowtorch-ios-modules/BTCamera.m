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
        [self _showCamera:params callback:callback];
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

- (void)_showCamera:(NSDictionary*)data callback:(BTCallback)callback {
    if (picker) {
        [picker.view removeFromSuperview];
    }
    picker = [[UIImagePickerController alloc] init];
    NSString* source = data[@"source"];
    if (!source) { source = @"camera"; }
    if ([source isEqualToString:@"photoLibrary"]) {
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    } else if ([source isEqualToString:@"savedPhotosAlbum"]) {
        picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    } else if ([source isEqualToString:@"camera"]) {
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        if (!!data[@"frontFacing"] && [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront]) {
            picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        picker.showsCameraControls = !data[@"hideControls"];
    } else {
        callback([NSString stringWithFormat:@"Unknown source type %@", source], nil);
        return;
    }
    
    picker.allowsEditing = !!data[@"allowEditing"];
    picker.delegate = self;
    
    BTAppDelegate* app = [BTAppDelegate instance];
    if (data[@"position"]) {
        picker.view.frame = [data[@"position"] makeRect];
        [app.webView.superview insertSubview:picker.view belowSubview:app.webView];
        callback(nil,nil);
    } else {
        [app.window.rootViewController presentViewController:picker animated:YES completion:NULL];
        captureParams = data;
        captureCallback = callback;
    }
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
    NSString* file = [BTFiles path:captureParams];
    BOOL success = [data writeToFile:file atomically:YES];
    if (!success) { return captureCallback(@"Could not store image", nil); }
    
    NSDictionary* response = @{ @"file":file, @"width":[NSNumber numberWithFloat:image.size.width], @"height":[NSNumber numberWithFloat:image.size.height] };
    if (captureParams[@"position"]) {
        captureCallback(nil, response);
        picker = nil;
    } else {
        [BTAppDelegate.instance.window.rootViewController dismissViewControllerAnimated:YES completion:^{
            captureCallback(nil, response);
            picker = nil;
        }];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)thePicker {
    if (captureParams && !captureParams[@"position"]) {
        [BTAppDelegate.instance.window.rootViewController dismissViewControllerAnimated:YES completion:NULL];
    }
    [BTAppDelegate notify:@"BTCamera.imagePickerControllerDidCancel"];
    picker = nil;
}
@end
