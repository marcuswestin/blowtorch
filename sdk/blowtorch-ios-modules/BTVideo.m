//
//  BTVideo.m
//  dogo
//
//  Created by Marcus Westin on 5/7/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTVideo.h"
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "BTFiles.h"

@implementation BTVideo {
    MPMoviePlayerController* moviePlayer;
    BTCallback playCallback;
    BTEnumeration* movieControlStyle;
}

static BTVideo* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    movieControlStyle = [[[[BTEnumeration enum:@"movieControlStyle"
                         default:MPMovieControlStyleDefault string:@"default"]
                         add:MPMovieControlStyleEmbedded string:@"embedded"]
                         add:MPMovieControlStyleFullscreen string:@"fullscreen"]
                         add:MPMovieControlStyleNone string:@"none"];
    
    [app handleCommand:@"BTVideo.play" handler:^(id params, BTCallback callback) {
        playCallback = callback;
        NSString* file = [BTFiles path:params];
        NSURL* url = (file ? [NSURL fileURLWithPath:file] : [NSURL URLWithString:params[@"url"]]);
        moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:moviePlayer];
        
        moviePlayer.controlStyle = [movieControlStyle from:params];
        moviePlayer.shouldAutoplay = YES;
        [app.window.rootViewController.view addSubview:moviePlayer.view];
        [moviePlayer setFullscreen:YES animated:YES];
    }];
}

- (void) _playbackDidFinish:(NSNotification*)notification {
    if (!playCallback) { return; }
    [moviePlayer setFullscreen:NO animated:YES];
    int reason = [[[notification userInfo] valueForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    if (reason == MPMovieFinishReasonPlaybackEnded) {
        playCallback(nil, @{ @"reason":@"playbackEnded" });
    } else if (reason == MPMovieFinishReasonUserExited) {
        playCallback(nil, @{ @"reason":@"userExited" });
    } else if (reason == MPMovieFinishReasonPlaybackError) {
        playCallback(@{ @"message":@"There was a playback error" }, nil);
    }
    playCallback = NULL;
    moviePlayer = nil;
}

@end
