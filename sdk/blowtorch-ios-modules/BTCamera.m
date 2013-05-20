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
#import <MobileCoreServices/UTCoreTypes.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@implementation BTCamera {
    UIImagePickerController* picker;
    BTCallback captureCallback;
    NSDictionary* captureParams;
    BTEnumeration* videoQuality;
    BTEnumeration* cameraCaptureMode;
    BTEnumeration* sourceType;
    BTEnumeration* cameraFlashMode;
    BTEnumeration* cameraDevice;
}

static BTCamera* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;

    sourceType = [[[BTEnumeration enum:@"sourceType"
                  default:UIImagePickerControllerSourceTypeCamera string:@"camera"]
                  add:UIImagePickerControllerSourceTypePhotoLibrary string:@"photoLibrary"]
                  add:UIImagePickerControllerSourceTypeSavedPhotosAlbum string:@"savedPhotosAlbum"];
    
    videoQuality = [[[[[[BTEnumeration enum:@"videoQuality"
                    default:UIImagePickerControllerQualityTypeMedium string:@"medium"]
                    add:UIImagePickerControllerQualityTypeLow string:@"low"]
                    add:UIImagePickerControllerQualityTypeHigh string:@"high"]
                    add:UIImagePickerControllerQualityType640x480 string:@"640x480"]
                    add:UIImagePickerControllerQualityTypeIFrame960x540 string:@"iFrame960x540"]
                    add:UIImagePickerControllerQualityTypeIFrame1280x720 string:@"iFrame1280x720"];
    
    cameraCaptureMode = [[BTEnumeration enum:@"cameraCaptureMode"
                  default:UIImagePickerControllerCameraCaptureModePhoto string:@"photo"]
                  add:UIImagePickerControllerCameraCaptureModeVideo string:@"video"];
    
    cameraFlashMode = [[[BTEnumeration enum:@"cameraFlashMode"
                 default:UIImagePickerControllerCameraFlashModeAuto string:@"auto"]
                 add:UIImagePickerControllerCameraFlashModeOff string:@"off"]
                 add:UIImagePickerControllerCameraFlashModeOn string:@"on"];
    
    cameraDevice = [[BTEnumeration enum:@"cameraDevice"
                    default:UIImagePickerControllerCameraDeviceRear string:@"rear"]
                    add:UIImagePickerControllerCameraDeviceFront string:@"front"];
    
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
        if ([cameraCaptureMode from:params is:@"video"]) {
            [picker startVideoCapture];
        } else {
            [picker takePicture];
        }
    }];
    
    [app handleCommand:@"BTCamera.stopCapture" handler:^(id params, BTCallback callback) {
        [picker stopVideoCapture];
    }];
}



- (void)_showCamera:(NSDictionary*)data callback:(BTCallback)callback {
    if (picker) {
        [picker.view removeFromSuperview];
    }
    picker = [[UIImagePickerController alloc] init];
    picker.sourceType = [sourceType from:data];
    if ([sourceType value:picker.sourceType is:@"camera"]) {
        if ([UIImagePickerController isCameraDeviceAvailable:[cameraDevice from:data]]) {
            picker.cameraDevice = [cameraDevice from:data];
        }
        
        if ([cameraCaptureMode from:data is:@"video"]) {
            [UIImagePickerController availableMediaTypesForSourceType:picker.sourceType];
            picker.videoQuality = [videoQuality from:data];
            picker.mediaTypes = @[(NSString*)kUTTypeMovie];
            NSTimeInterval max = [data[@"videoMaximumDuration"] doubleValue];
            picker.videoMaximumDuration = max;
        }
        picker.cameraCaptureMode = [cameraCaptureMode from:data];

        picker.cameraFlashMode = [cameraFlashMode from:data];
        
        picker.showsCameraControls = ![data[@"hideControls"] boolValue];
    } else {
        picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:picker.sourceType];
    }
    
    picker.allowsEditing = [data[@"allowEditing"] boolValue];
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
    if ([info[UIImagePickerControllerMediaType] isEqualToString:(NSString *)kUTTypeMovie]) {
        [self _handleCapturedVideo:info];
    } else {
        [self _handleCapturedPicture:info];
    }
}

- (void) _handleCapturedVideo:(NSDictionary*)info {
    NSURL* videoUrl = info[UIImagePickerControllerMediaURL];
    NSString *file = videoUrl.path;
    if (captureParams[@"saveToAlbum"] && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(file)) {
        UISaveVideoAtPathToSavedPhotosAlbum(file, nil, nil, nil);
    }
    
    AVAsset* videoAsset = [AVAsset assetWithURL:videoUrl];
    AVAssetTrack* videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo][0];
    CGSize videoSize = [videoTrack naturalSize];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoAsset];
    float durationInSeconds = CMTimeGetSeconds(playerItem.duration);
    
    NSString* thumbnailFile = @"";
    NSDictionary* thumbParams = captureParams[@"videoThumbnail"];
    if (thumbParams) {
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:videoAsset];
        imageGenerator.appliesPreferredTrackTransform = YES;
        double time = [thumbParams[@"time"] doubleValue];
        if (time > durationInSeconds) { time = durationInSeconds; }
        CMTime thumbTime = CMTimeMakeWithSeconds(time, playerItem.duration.timescale);
        NSError *error = nil;
        CGImageRef imageRef = [imageGenerator copyCGImageAtTime:thumbTime actualTime:NULL error:&error];
        if (error) { return [self _error:error response:nil]; }
        UIImage *thumbImage = [[UIImage alloc] initWithCGImage:imageRef];
        NSData *data;
        if ([@"png" isEqualToString:thumbParams[@"format"]]) {
            data = UIImagePNGRepresentation(thumbImage);
        } else {
            NSNumber* jpegCompressionQuality = thumbParams[@"jpegCompressionQuality"];
            data = UIImageJPEGRepresentation(thumbImage, jpegCompressionQuality ? [jpegCompressionQuality floatValue] : 0.80);
        }
        CGImageRelease(imageRef);
        
        thumbnailFile = [BTFiles path:captureParams];
        BOOL success = [data writeToFile:thumbnailFile atomically:YES];
        if (!success) { return [self _error:@"Could not write video thumbnail to file" response:nil]; }
    }
    
    [self _error:nil response:@{
     @"type":@"video",
     @"file":file, @"duration":[NSNumber numberWithFloat:durationInSeconds],
     @"width":[NSNumber numberWithFloat:videoSize.width], @"height":[NSNumber numberWithFloat:videoSize.height],
     @"thumbnailFile":thumbnailFile
     }];
}

- (void) _handleCapturedPicture:(NSDictionary*)info {
    if (captureParams[@"saveToAlbum"]) {
        UIImageWriteToSavedPhotosAlbum(info[UIImagePickerControllerOriginalImage], nil, nil, nil);
    }
    
    UIImage* image = captureParams[@"allowEditing"] ? info[UIImagePickerControllerEditedImage] : info[UIImagePickerControllerOriginalImage];
    
    NSString* resize = captureParams[@"resize"];
    if (resize) {
        image = [image thumbnailSize:[resize makeSize] transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationDefault];
    }
    
    NSData* data;
    if ([@"png" isEqualToString:captureParams[@"format"]]) {
        data = UIImagePNGRepresentation(image);
    } else {
        NSNumber* jpegCompressionQuality = captureParams[@"jpegCompressionQuality"];
        data = UIImageJPEGRepresentation(image, jpegCompressionQuality ? [jpegCompressionQuality floatValue] : 0.80);
    }
    
    NSString* file = [BTFiles path:captureParams];
    BOOL success = [data writeToFile:file atomically:YES];
    if (!success) { return [self _error:@"Could not write result to file" response:nil]; }
    
    [self _error:nil response:@{
     @"type":@"picture",
     @"file":file, @"width":[NSNumber numberWithFloat:image.size.width], @"height":[NSNumber numberWithFloat:image.size.height]
     }];
}

- (void) _error:(id)error response:(id)response {
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
