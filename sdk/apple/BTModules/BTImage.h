//
//  BTImage.h
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTModule.h"

#if defined BT_PLATFORM_OSX
    #define BT_IMAGE_TYPE NSImage
#elif defined BT_PLATFORM_IOS
    #define BT_IMAGE_TYPE UIImage
    #import "UIImage+Resize.h"
#endif

@interface BTImage : BTModule

+ (BT_IMAGE_TYPE*)imageWithData:(NSData*)data;
+ (NSData*)resize:(BT_IMAGE_TYPE*)image size:(CGSize)size;
+ (NSData*)crop:(BT_IMAGE_TYPE*)image size:(CGSize)size;
+ (NSData*)crop:(BT_IMAGE_TYPE*)image rect:(CGRect)rect;

@end
