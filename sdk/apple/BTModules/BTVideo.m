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

- (void)setup {
    if (instance) { return; }
    instance = self;
    
    movieControlStyle = [[[[BTEnumeration enum:@"movieControlStyle"
                         default:MPMovieControlStyleDefault string:@"default"]
                         add:MPMovieControlStyleEmbedded string:@"embedded"]
                         add:MPMovieControlStyleFullscreen string:@"fullscreen"]
                         add:MPMovieControlStyleNone string:@"none"];
    
    [BTApp handleCommand:@"BTVideo.play" handler:^(id params, BTCallback callback) {
        playCallback = callback;
        NSString* file = [BTFiles path:params];
        NSURL* url = (file ? [NSURL fileURLWithPath:file] : [NSURL URLWithString:params[@"url"]]);
        moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:moviePlayer];
        
        moviePlayer.controlStyle = [movieControlStyle from:params];
        moviePlayer.shouldAutoplay = YES;

        [BTApp.instance.window.rootViewController.view addSubview:moviePlayer.view];
        
        [self _fullScreen:YES animated:YES];
    }];
}

- (void) _fullScreen:(BOOL)fullScreen animated:(BOOL)flag {
    [[UIApplication sharedApplication] setStatusBarHidden:fullScreen withAnimation:flag ? UIStatusBarAnimationFade : NO];
    [moviePlayer setFullscreen:fullScreen animated:flag];
}

- (void) _playbackDidFinish:(NSNotification*)notification {
    if (!playCallback) { return; }
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:NO];
    [self _fullScreen:NO animated:YES];
    
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
