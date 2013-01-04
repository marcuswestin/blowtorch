#import "BTFacebook.h"

@implementation BTFacebook {
    Facebook* _facebook;
}

- (id)init {
    if (self = [super init]) {
        _facebook = [[Facebook alloc] initWithAppId:FBSession.defaultAppID andDelegate:nil];
//        [FBSettings setLoggingBehavior:[NSSet setWithObjects:FBLoggingBehaviorFBRequests, FBLoggingBehaviorFBURLConnections, FBLoggingBehaviorAccessTokens, FBLoggingBehaviorSessionStateTransitions, nil]];
    }
    return self;
}

- (void)setup:(BTAppDelegate *)app {
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(appDidBecomeActive) name:@"app.didBecomeActive" object:nil];
    [center addObserver:self selector:@selector(appWillTerminate) name:@"app.willTerminate" object:nil];
    
    [app registerHandler:@"facebook.connect" handler:^(id data, BTResponseCallback responseCallback) {
        [FBSession openActiveSessionWithReadPermissions:[data objectForKey:@"permissions"] allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
            NSLog(@"FBSession.open result %@ %d %@", session, state, error);
            
            NSMutableDictionary *facebookSession = [NSMutableDictionary dictionary];
            NSNumber* expirationDate = [NSNumber numberWithDouble:[session.expirationDate timeIntervalSince1970]];
            if (session.accessToken) {
                [facebookSession setObject:session.accessToken forKey:@"accessToken"];
                [facebookSession setObject:expirationDate forKey:@"expirationDate"];
                _facebook.accessToken = session.accessToken;
                _facebook.expirationDate = session.expirationDate;
            }
            
            NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                                  facebookSession, @"facebookSession",
                                  [NSNumber numberWithInt:state], @"state",
                                  nil];
            
            responseCallback(nil, info);
            [app notify:@"facebook.sessionStateChanged" info:info];
        }];
    }];
    // DO WE NEED THIS?
    //        case FBSessionStateClosed: {
    //            [FBSession.activeSession closeAndClearTokenInformation];
    
    [app registerHandler:@"facebook.dialog" handler:^(id data, BTResponseCallback responseCallback) {
        if (!FBSession.activeSession) {
            return responseCallback(@"No active FB session", nil);
        }
        _facebook.accessToken = FBSession.activeSession.accessToken;
        _facebook.expirationDate = FBSession.activeSession.expirationDate;
        NSString* dialog = [data objectForKey:@"dialog"]; // oauth, feed, and apprequests
        NSMutableDictionary* params = [NSMutableDictionary dictionaryWithDictionary:[data objectForKey:@"params"]]; // so silly
        [_facebook dialog:dialog andParams:params andDelegate:self];
    }];
    [app registerHandler:@"facebook.clear" handler:^(id data, BTResponseCallback responseCallback) {
        if (FBSession.activeSession) {
            [FBSession.activeSession closeAndClearTokenInformation];
        }
        responseCallback(nil, nil);
    }];
}

+ (BOOL)handleOpenURL:(NSURL *)url {
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)appDidBecomeActive {
    if (!FBSession.activeSession) { return; }
    [FBSession.activeSession handleDidBecomeActive];
}

- (void)appWillTerminate {
    if (!FBSession.activeSession) { return; }
    [FBSession.activeSession close];
}

/**
 * Called when the dialog succeeds and is about to be dismissed.
 */
- (void)dialogDidComplete:(FBDialog *)dialog {
    [BTAppDelegate notify:@"facebook.dialogDidComplete"];
}

/**
 * Called when the dialog succeeds with a returning url.
 */
- (void)dialogCompleteWithUrl:(NSURL *)url {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (url) { [info setObject:[url absoluteString] forKey:@"url"]; }
    [BTAppDelegate notify:@"facebook.dialogCompleteWithUrl" info:info];
}

/**
 * Called when the dialog get canceled by the user.
 */
- (void)dialogDidNotCompleteWithUrl:(NSURL *)url {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (url) { [info setObject:[url absoluteString] forKey:@"url"]; }
    [BTAppDelegate notify:@"facebook.dialogDidNotCompleteWithUrl" info:info];
}

/**
 * Called when the dialog is cancelled and is about to be dismissed.
 */
- (void)dialogDidNotComplete:(FBDialog *)dialog {
    [BTAppDelegate notify:@"facebook.dialogDidNotComplete"];
}

/**
 * Called when dialog failed to load due to an error.
 */
- (void)dialog:(FBDialog*)dialog didFailWithError:(NSError *)error {
    [BTAppDelegate notify:@"facebook.dialogDidFailWithError"];
}

@end
