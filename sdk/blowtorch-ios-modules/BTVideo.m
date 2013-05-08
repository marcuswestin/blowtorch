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

@implementation BTVideo {
    MPMoviePlayerController* moviePlayer;
    BTCallback playCallback;
}

static BTVideo* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    [app handleCommand:@"BTVideo.play" handler:^(id params, BTCallback callback) {
        playCallback = callback;
        NSURL *url = [NSURL URLWithString:params[@"url"]];
        moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:moviePlayer];
        
        moviePlayer.controlStyle = MPMovieControlModeDefault;
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