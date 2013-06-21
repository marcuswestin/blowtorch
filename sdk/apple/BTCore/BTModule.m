//
//  BTModule.m
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import "BTModule.h"
#import "BTApp.h"

@implementation BTModule

static NSMutableDictionary* modules;

static const NSString* AllModules = @"BTFiles,BTImage,BTCache,BTAddressBook,BTSql,BTNotifications,BTNet,BTVideo,BTCamera,BTSplashScreen";

/* Module setup
 **************/
+ (void)_setupAll {
    modules = [NSMutableDictionary dictionary];
    [BTApp handleCommand:@"BTModule.getMedia" handler:^(id data, BTCallback callback) {
        [BTModule module:data[@"module"] getMedia:data[@"mediaId"] callback:callback];
    }];

    NSArray* modules = [AllModules componentsSeparatedByString:@","];
    for (NSString* moduleName in modules) {
        Class BTModuleClass = NSClassFromString(moduleName);
        if (!BTModuleClass) { continue; }
        [BTModuleClass setup];
    }
}

+ (void) setup {
    BTModule* module = [[self alloc] init];
    NSString* moduleName = [module moduleName];
    if (modules[moduleName]) {
        [NSException raise:@"BTModuleException" format:@"Module %@ has already been setup", moduleName];
    }
    modules[moduleName] = module;
    [module setup];
}

- (void) setup {
    [NSException raise:@"NotImplemented" format:@"Module %@ has not implemented setup:", [self moduleName]];
}

- (void)notify:(NSString *)event {
    return [self notify:event info:nil];
}
- (void)notify:(NSString *)event info:(NSDictionary *)info {
    [BTApp notify:event info:info];
}

/* Utils
 *******/

+ (NSString*) moduleName { return NSStringFromClass(self); }
- (NSString*) moduleName { return [self.class moduleName]; }

+ (void)module:(NSString *)moduleName getMedia:(NSString *)mediaId callback:(BTCallback)callback {
    BTModule* module = modules[moduleName];
    [module getMedia:mediaId callback:callback];
}
- (void)getMedia:(NSString *)mediaId callback:(BTCallback)callback {
    callback([NSString stringWithFormat:@"Module %@ has not implemented getMedia:", [self moduleName]], nil);
}

- (void)async:(void (^)())asyncBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), asyncBlock);
}

- (void)asyncBackground:(void (^)())asyncBackgroundPriorityBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), asyncBackgroundPriorityBlock);
}

- (void)asyncHighPriority:(void (^)())asyncHighPriorityBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), asyncHighPriorityBlock);
}

- (void)asyncLowPriority:(void (^)())asyncLowPriorityBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), asyncLowPriorityBlock);
}

- (void)asyncMainQueue:(void (^)())asyncMainBlock {
    dispatch_async(dispatch_get_main_queue(), asyncMainBlock);
}

@end
