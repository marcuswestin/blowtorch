//
//  BTNotifications.m
//  dogo
//
//  Created by Marcus Westin on 3/29/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTNotifications.h"

static BTNotifications* instance;

@implementation BTNotifications {
    BTCallback registerCallback;
}

- (void)setup {
    if (instance) { return; }
    instance = self;
    
    [BTApp handleCommand:@"BTNotifications.register" handler:^(id params, BTCallback callback) {
        registerCallback = callback;
        UIRemoteNotificationType types = (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert);
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:types];
    }];
    
    [BTApp handleCommand:@"BTNotifications.getAuthorizationStatus" handler:^(id params, BTCallback callback) {
        UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        if (types == UIRemoteNotificationTypeNone) { return callback(nil, nil); }

        NSMutableDictionary* res = [NSMutableDictionary dictionary];
        if (types | UIRemoteNotificationTypeAlert) { res[@"alert"] = [NSNumber numberWithBool:YES]; }
        if (types | UIRemoteNotificationTypeBadge) { res[@"badge"] = [NSNumber numberWithBool:YES]; }
        if (types | UIRemoteNotificationTypeSound) { res[@"sound"] = [NSNumber numberWithBool:YES]; }
        callback(nil, res);
    }];
    
    [BTApp handleCommand:@"BTNotifications.setBadgeNumber" handler:^(id params, BTCallback callback) {
        NSInteger number = [[UIApplication sharedApplication] applicationIconBadgeNumber];
        if (params[@"number"]) {
            number = [params[@"number"] integerValue];
        } else if (params[@"increment"]) {
            number += [params[@"increment"] integerValue];
        } else if (params[@"decrement"]) {
            number -= [params[@"decrement"] integerValue];
        }
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:number];
        callback(nil, nil);
    }];
    
    NSNotificationCenter* notifications = [NSNotificationCenter defaultCenter];
    [notifications addObserver:self selector:@selector(handleDidRegister:) name:@"application.didRegisterForRemoteNotifications" object:nil];
    [notifications addObserver:self selector:@selector(handleDidLaunchWithNotification:) name:@"application.didLaunchWithNotification" object:nil];
    [notifications addObserver:self selector:@selector(handleDidReceiveRemoteNotification:) name:@"application.didReceiveRemoteNotification" object:nil];
    [notifications addObserver:self selector:@selector(handleDidFailToRegister:) name:@"application.didFailToRegisterForRemoteNotifications" object:nil];
}

- (void) handleDidFailToRegister:(NSNotification*)notification {
    [self notify:@"BTNotifications.registerFailed" info:nil];
    if (registerCallback) { registerCallback(@"Notifications were not allowed.", nil); }
    registerCallback = nil;
}

- (void) handleDidLaunchWithNotification:(NSNotification*)notification {
    NSDictionary* launchNotification = notification.userInfo[@"launchNotification"];
    [self handlePushNotification:launchNotification didBringAppToForeground:YES];
}

- (void) handleDidRegister:(NSNotification*)notification {
    NSString * tokenAsString = [[[notification.userInfo[@"deviceToken"] description]
                                 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]]
                                stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSDictionary* info = @{ @"pushToken":tokenAsString, @"pushType":@"ios" };
    [self notify:@"BTNotifications.registered" info:info];
    if (registerCallback) { registerCallback(nil, info); }
    registerCallback = nil;
}

- (void) handleDidReceiveRemoteNotification:(NSNotification*)notification {
    [self handlePushNotification:notification.userInfo[@"notification"] didBringAppToForeground:([UIApplication sharedApplication].applicationState != UIApplicationStateActive)];
}

- (void)handlePushNotification:(NSDictionary *)notification didBringAppToForeground:(BOOL)didBringAppToForeground {
    NSDictionary* info = @{
                           @"data":notification,
                           @"didBringAppIntoForeground":[NSNumber numberWithBool:(didBringAppToForeground)]
                           };
    [self notify:@"BTNotifications.notification" info:info];
}

@end
