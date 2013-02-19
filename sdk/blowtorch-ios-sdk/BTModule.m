//
//  BTModule.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTModule.h"

static BTModule* instance;

@implementation BTModule

+ (BTModule*)instance { return instance; }

+ (void) setup:(BTAppDelegate*)app {
    BTModule* module = [[self alloc] init];
    instance = module;
    [module setup:app];
}
// override this in module instances
- (void) setup:(BTAppDelegate*)app {}

@end
