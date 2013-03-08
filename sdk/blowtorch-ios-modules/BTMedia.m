//
//  BTMedia.m
//  dogo
//
//  Created by Marcus Westin on 3/6/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTMedia.h"
#import "WebViewProxy.h"
#import "BTNet.h"

static BTMedia* instance;

@implementation BTMedia {
    NSMutableDictionary* _mediaCache;
    BTResponseCallback _callback;
}

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    NSString* mediaPrefix = @"/blowtorch/media/";
    [WebViewProxy handleRequestsWithHost:app.serverHost pathPrefix:mediaPrefix handler:^(NSURLRequest *req, WVPResponse *res) {
        NSString* file = [req.URL.path substringFromIndex:mediaPrefix.length];
        NSString* format = [file pathExtension];
        NSString* mediaId = [file stringByDeletingPathExtension];
        UIImage* image = [_mediaCache objectForKey:mediaId];
        NSData* data;
        NSString* mimeType;
        if ([format isEqualToString:@"png"]) {
            data = UIImagePNGRepresentation(image);
            mimeType = @"image/png";
        } else if ([format isEqualToString:@"jpg"] || [format isEqualToString:@"jpeg"]) {
            data = UIImageJPEGRepresentation(image, 1.0);
            mimeType = @"image/jpg";
        } else {
            return;
        }
        [res respondWithData:data mimeType:mimeType];
    }];
    
    [app registerHandler:@"media.upload" handler:^(id data, BTResponseCallback responseCallback) {
        [self uploadMedia:data responseCallback:responseCallback];
    }];
    
    [app registerHandler:@"media.pick" handler:^(id data, BTResponseCallback callback) {
        [self pickMedia:data callback:callback];
    }];
}


- (void)pickMedia:(NSDictionary*)data callback:(BTResponseCallback)callback {
    if (!_mediaCache) { _mediaCache = [NSMutableDictionary dictionary]; }
    
    UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
    NSString* source = [data objectForKey:@"source"];
    if (!source) {
        source = @"libraryPhotos";
    }
    
    if ([source isEqualToString:@"libraryPhotos"]) {
        mediaUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    } else if ([source isEqualToString:@"librarySavedPhotos"]) {
        mediaUI.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    } else if ([source isEqualToString:@"camera"]) {
        mediaUI.sourceType = UIImagePickerControllerSourceTypeCamera;
        if ([@"front" isEqualToString:[data objectForKey:@"cameraDevice"]]) {
            if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront]) {
                mediaUI.cameraDevice = UIImagePickerControllerCameraDeviceFront;
            }
        }
    } else {
        return callback(@"Unknown source", nil);
    }
    
    if ([data objectForKey:@"allowsEditing"]) {
        mediaUI.allowsEditing = YES;
    } else {
        mediaUI.allowsEditing = NO;
    }
    
    mediaUI.delegate = self;
    
    _callback = callback;
    
    [BTAppDelegate.instance.window.rootViewController presentViewController:mediaUI animated:YES completion:^{}];
}

static int uniqueId = 1;
- (NSString *)unique {
    int thisId = ++uniqueId;
    return [NSString stringWithFormat:@"%d", thisId];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    NSString* mediaId = [self unique];
    [_mediaCache setObject:image forKey:mediaId];
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                          mediaId, @"mediaId",
                          [NSNumber numberWithFloat:image.size.width], @"width",
                          [NSNumber numberWithFloat:image.size.height], @"height",
                          nil];
    [BTAppDelegate.instance.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        _callback(nil, info);
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [BTAppDelegate.instance.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        _callback(nil, [NSDictionary dictionary]);
    }];
}

- (void)uploadMedia:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback {
    NSDictionary* mediaParts = [data objectForKey:@"parts"];
    NSMutableDictionary* attachments = [NSMutableDictionary dictionaryWithCapacity:mediaParts.count];
    for (NSString* name in mediaParts) {
        UIImage* image = [_mediaCache objectForKey:[mediaParts objectForKey:name]];
        [attachments setObject:UIImagePNGRepresentation(image) forKey:name];
    }
    [BTNet post:[data objectForKey:@"url"] json:[data objectForKey:@"jsonParams"] attachments:attachments headers:[data objectForKey:@"headers"] boundary:[data objectForKey:@"boundary"] responseCallback:responseCallback];
}

@end
