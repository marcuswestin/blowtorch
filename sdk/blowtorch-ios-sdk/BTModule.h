//
//  BTModule.h
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSArray+HHFunctional.h"
#import "NSArray+NSString+HHMakeStructs.h"
#import "NSString+HHUriEncoding.h"
#import "BTAppDelegate.h"

@interface BTModule : NSObject
+ (BTModule*) instance;
+ (void) setup:(BTAppDelegate*)app;
- (void) setup:(BTAppDelegate*)app;
@end
