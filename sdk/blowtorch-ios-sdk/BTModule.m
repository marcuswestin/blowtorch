//
//  BTModule.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTModule.h"

@implementation BTModule

static NSMutableDictionary* modules;

/* Module setup
 **************/
+ (void) setup:(BTAppDelegate*)app {
    if (!modules) { [self _init:app]; }
    BTModule* module = [[self alloc] init];
    NSString* moduleName = [module moduleName];
    if (modules[moduleName]) {
        [NSException raise:@"BTModuleException" format:@"Module %@ has already been setup", moduleName];
    }
    modules[moduleName] = module;
    [module setup:app];
}
- (void) setup:(BTAppDelegate*)app {
    [NSException raise:@"NotImplemented" format:@"Module %@ has not implemented setup:", [self moduleName]];
}

/* Utils
 *******/

+ (void) _init:(BTAppDelegate*)app {
    modules = [NSMutableDictionary dictionary];
    [app registerHandler:@"BTModule.getMedia" handler:^(id data, BTResponseCallback callback) {
        [BTModule module:data[@"module"] getMedia:data[@"mediaId"] callback:callback];
    }];
}

+ (NSString*) moduleName { return NSStringFromClass(self); }
- (NSString*) moduleName { return [self.class moduleName]; }

+ (void)module:(NSString *)moduleName getMedia:(NSString *)mediaId callback:(BTResponseCallback)callback {
    BTModule* module = modules[moduleName];
    [module getMedia:mediaId callback:callback];
}
- (void)getMedia:(NSString *)mediaId callback:(BTResponseCallback)callback {
    callback([NSString stringWithFormat:@"Module %@ has not implemented getMedia:", [self moduleName]], nil);
}

- (void)async:(void (^)())asyncBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), asyncBlock);
}

@end
