//
//  UIColor+Util.m
//  dogo
//
//  Created by Marcus Westin on 1/23/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "UIColor+Util.h"

@implementation UIColor (Util)

+ (UIColor *)r:(int)r g:(int)g b:(int)b {
    return [UIColor r:r g:g b:b a:1.0];
}

+ (UIColor *)r:(int)r g:(int)g b:(int)b a:(float)a {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

@end
