#import "BTFacebook.h"

@implementation BTFacebook {
    Facebook* _facebook;
}

static BTFacebook* instance;

- (id)init {
    if (self = [super init]) {
        _facebook = [[Facebook alloc] initWithAppId:FBSession.defaultAppID andDelegate:nil];
//        [FBSettings setLoggingBehavior:[NSSet setWithObjects:FBLoggingBehaviorFBRequests, FBLoggingBehaviorFBURLConnections, FBLoggingBehaviorAccessTokens, FBLoggingBehaviorSessionStateTransitions, nil]];
    }
    return self;
}

- (void)setup:(BTAppDelegate *)app {
    instance = self;
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(appDidBecomeActive) name:@"app.didBecomeActive" object:nil];
    [center addObserver:self selector:@selector(appWillTerminate) name:@"app.willTerminate" object:nil];
    
    [app handleCommand:@"BTFacebook.connect" handler:^(id data, BTCallback responseCallback) {
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
            [app notify:@"BTFacebook.sessionStateChanged" info:info];
        }];
    }];
    // DO WE NEED THIS?
    //        case FBSessionStateClosed: {
    //            [FBSession.activeSession closeAndClearTokenInformation];
    
    [app handleCommand:@"BTFacebook.request" handler:^(id data, BTCallback responseCallback) {
        if (!FBSession.activeSession) {
            return responseCallback(@"No active FB session", nil);
        }
        [[FBRequest requestForGraphPath:[data objectForKey:@"path"]] startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Facebook graph request error %@", error);
                return responseCallback(@"I was unable to connect to Facebook", nil);
            }
            responseCallback(nil, result);
        }];
    }];
    
    [app handleCommand:@"BTFacebook.dialog" handler:^(id data, BTCallback responseCallback) {
        if (!FBSession.activeSession) {
            return responseCallback(@"No active FB session", nil);
        }
        _facebook.accessToken = FBSession.activeSession.accessToken;
        _facebook.expirationDate = FBSession.activeSession.expirationDate;
        NSString* dialog = [data objectForKey:@"dialog"]; // oauth, feed, and apprequests
        NSMutableDictionary* params = [NSMutableDictionary dictionaryWithDictionary:[data objectForKey:@"params"]]; // so silly
        [_facebook dialog:dialog andParams:params andDelegate:self];
    }];
    [app handleCommand:@"BTFacebook.clear" handler:^(id data, BTCallback responseCallback) {
        if (FBSession.activeSession) {
            [FBSession.activeSession closeAndClearTokenInformation];
        }
        responseCallback(nil, nil);
    }];
}

+ (BOOL)handleOpenURL:(NSURL *)url {
    if (!FBSession.activeSession) { return NO; }
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
    [BTAppDelegate notify:@"BTFacebook.dialogDidComplete"];
}

/**
 * Called when the dialog succeeds with a returning url.
 */
- (void)dialogCompleteWithUrl:(NSURL *)url {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (url) { [info setObject:[url absoluteString] forKey:@"url"]; }
    [BTAppDelegate notify:@"BTFacebook.dialogCompleteWithUrl" info:info];
}

/**
 * Called when the dialog get canceled by the user.
 */
- (void)dialogDidNotCompleteWithUrl:(NSURL *)url {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (url) { [info setObject:[url absoluteString] forKey:@"url"]; }
    [BTAppDelegate notify:@"BTFacebook.dialogDidNotCompleteWithUrl" info:info];
}

/**
 * Called when the dialog is cancelled and is about to be dismissed.
 */
- (void)dialogDidNotComplete:(FBDialog *)dialog {
    [BTAppDelegate notify:@"BTFacebook.dialogDidNotComplete"];
}

/**
 * Called when dialog failed to load due to an error.
 */
- (void)dialog:(FBDialog*)dialog didFailWithError:(NSError *)error {
    [BTAppDelegate notify:@"BTFacebook.dialogDidFailWithError"];
}

@end
