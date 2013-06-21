//
//  BTNotifications.m
//  dogo
//
//  Created by Marcus Westin on 3/29/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTNotifications.h"

static BTNotifications* instance;

#if defined BT_PLATFORM_OSX
    #define ApplicationStateActive NSApplicationState
    #define NotificationTypes (UIRemoteNotificationTypeBadge)
    #define BT_PUSH_TYPE @"osx"
#elif defined BT_PLATFORM_IOS
    #define ApplicationStateActive NSApplicationState
    #define NotificationTypes (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)
    #define BT_PUSH_TYPE @"ios"
#endif

#define RemoteNotificationTypeAlert BT(RemoteNotificationTypeAlert)

@implementation BTNotifications {
    BTCallback registerCallback;
}

- (void)setup {
    if (instance) { return; }
    instance = self;
    
    [BTApp handleCommand:@"BTNotifications.register" handler:^(id params, BTCallback callback) {
        registerCallback = callback;
        [BTSharedApplication registerForRemoteNotificationTypes:(BT(RemoteNotificationTypeAlert) | BT(RemoteNotificationTypeBadge) | BT(RemoteNotificationTypeSound))];
    }];
    
    [BTApp handleCommand:@"BTNotifications.getAuthorizationStatus" handler:^(id params, BTCallback callback) {
        BT(RemoteNotificationType) types = [BTSharedApplication enabledRemoteNotificationTypes];
        if (types == BT(RemoteNotificationTypeNone)) { return callback(nil, nil); }

        NSMutableDictionary* res = [NSMutableDictionary dictionary];
        if (types | BT(RemoteNotificationTypeAlert)) { res[@"alert"] = [NSNumber numberWithBool:YES]; }
        if (types | BT(RemoteNotificationTypeBadge)) { res[@"badge"] = [NSNumber numberWithBool:YES]; }
        if (types | BT(RemoteNotificationTypeSound)) { res[@"sound"] = [NSNumber numberWithBool:YES]; }
        callback(nil, res);
    }];
    
    [BTApp handleCommand:@"BTNotifications.setBadgeNumber" handler:^(id params, BTCallback callback) {
        NSInteger number = [self _getBadgeNumber];
        if (params[@"number"]) {
            number = [params[@"number"] integerValue];
        } else if (params[@"increment"]) {
            number += [params[@"increment"] integerValue];
        } else if (params[@"decrement"]) {
            number -= [params[@"decrement"] integerValue];
        }
        [self _setBadgeNumber:number];

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
    NSDictionary* info = @{ @"pushToken":tokenAsString, @"pushType":BT_PUSH_TYPE };
    [self notify:@"BTNotifications.registered" info:info];
    if (registerCallback) { registerCallback(nil, info); }
    registerCallback = nil;
}

- (void)handlePushNotification:(NSDictionary *)notification didBringAppToForeground:(BOOL)didBringAppToForeground {
    NSDictionary* info = @{
                           @"data":notification,
                           @"didBringAppIntoForeground":[NSNumber numberWithBool:(didBringAppToForeground)]
                           };
    [self notify:@"BTNotifications.notification" info:info];
}

/* Platform specific OSX
 ***********************/
#if defined BT_PLATFORM_OSX
- (NSInteger) _getBadgeNumber {
    return 0;
}
- (void) _setBadgeNumber:(NSInteger)number {
}
- (void) handleDidReceiveRemoteNotification:(NSNotification*)notification {
    [self handlePushNotification:notification.userInfo[@"notification"] didBringAppToForeground:NO];
}
/* Platform specific iOS
 ***********************/
#elif defined BT_PLATFORM_IOS
- (NSInteger) _getBadgeNumber {
    return [BTSharedApplication applicationIconBadgeNumber];
}
- (void) _setBadgeNumber:(NSInteger)number {
    [BTSharedApplication setApplicationIconBadgeNumber:number];
}
- (void) handleDidReceiveRemoteNotification:(NSNotification*)notification {
    [self handlePushNotification:notification.userInfo[@"notification"] didBringAppToForeground:(BTSharedApplication.applicationState != UIApplicationStateActive)];
}
#endif

@end
