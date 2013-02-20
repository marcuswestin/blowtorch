//
//  BTAudio.m
//  dogo
//
//  Created by Marcus Westin on 1/10/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTAudio.h"
#import "BTNet.h"

@implementation BTAudio {
    AVAudioRecorder* _recorder;
    AVAudioPlayer* _player;
    AUGraph* _graph;
}

static BTAudio* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    [app registerHandler:@"audio.filter" handler:^(id data, BTResponseCallback responseCallback) {
        NSString* effect = [data objectForKey:@"effect"];
        if ([effect isEqualToString:@"squeek"]) {
//            NSNumber* amount = [data objectForKey:@"amount"];
            
        }
    }];
    
    [app registerHandler:@"audio.prepareRecording" handler:^(id data, BTResponseCallback responseCallback) {
        NSLog(@"Audio.prepare");
        NSString* errorMessage = @"I can't seem to activate the microphone. Sorry :(";
        AVAudioSessionCategoryOptions sessionOptions = 0;//AVAudioSessionCategoryOptionMixWithOthers;
        AVAudioSession* session = [self _activateSession:AVAudioSessionCategoryRecord options:sessionOptions];
        if (!session || !session.inputIsAvailable) {
            NSLog(@"ERROR activating microphone %d", session.inputAvailable);
            responseCallback(errorMessage, nil);
            return;
        }
        
        // http://stackoverflow.com/questions/2149280/proper-avaudiorecorder-settings-for-recording-voice
        NSMutableDictionary* recordSettings = [[NSMutableDictionary alloc] init];
        [recordSettings setObject:[NSNumber numberWithInt: kAudioFormatMPEG4AAC] forKey: AVFormatIDKey];
        [recordSettings setObject:[NSNumber numberWithFloat:16000.0] forKey: AVSampleRateKey];
        [recordSettings setObject:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
        [recordSettings setObject:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
        [recordSettings setObject:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
        [recordSettings setObject:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
        NSError* err;
        _recorder = [[AVAudioRecorder alloc] initWithURL:[BTAudio getFileLocation] settings:recordSettings error:&err];
        if (err) {
            NSLog(@"ERROR initWithURL:settings: %@", err);
            responseCallback(errorMessage, nil);
            return;
        }
        _recorder.delegate = self;
        [_recorder prepareToRecord];
        
        responseCallback(nil,nil);
    }];
    
    [app registerHandler:@"audio.record" handler:^(id data, BTResponseCallback responseCallback) {
        NSLog(@"Audio.record");
        BOOL success = [_recorder record];
        NSLog(@"Recording started %d", success);
        responseCallback(success ? nil : @"I can't seem to start recording. Sorry :(", nil);
        NSLog(@"Audio.record recording");
    }];
    
    [app registerHandler:@"audio.save" handler:^(id data, BTResponseCallback responseCallback) {
        NSURL* src = [BTAudio getFileLocation];
        NSURL* dst = [BTAudio getFileLocation:[data objectForKey:@"filename"]];
        NSError* err;
        [[NSFileManager defaultManager] moveItemAtURL:src toURL:dst error:&err];
        if (err) { return responseCallback(err, nil); }
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:dst error:&err];
        if (err) { return responseCallback(err, nil); }
        responseCallback(nil, [NSDictionary dictionaryWithObjectsAndKeys:
                               [dst absoluteString], @"location",
                               [NSNumber numberWithInt:_player.duration], @"duration",
                               nil]);
    }];
    
    [app registerHandler:@"audio.stopRecording" handler:^(id data, BTResponseCallback responseCallback) {
        [_recorder stop];
        [self _deactivateSession];
    }];
    
    [app registerHandler:@"audio.play" handler:^(id data, BTResponseCallback responseCallback) {
        if (![self _activateSession:AVAudioSessionCategoryPlayAndRecord options:0]) {
            responseCallback(@"Sorry, I can't seem to get the sound to play.", nil);
            return;
        }
        
        NSString* location = [data objectForKey:@"location"];
        NSURL* fileUrl = location ? [NSURL URLWithString:location] : [BTAudio getFileLocation];
        
        NSError* err;
//        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl error:&err];
        NSData* audioData = [NSData dataWithContentsOfURL:fileUrl];
        _player = [[AVAudioPlayer alloc] initWithData:audioData error:&err];
        if (err) {
            NSLog(@"ERROR PLAYING %@", err);
            return;
        }
        _player.numberOfLoops = 0;
        _player.delegate = self;
        
        NSLog(@"START PLAYING %@", [fileUrl absoluteString])
        BOOL success = [_player play];
        if (success) {
            NSLog(@"STARTED PLAYING");
        } else {
            NSLog(@"FAILED TO START PLAYING");
        }
    }];
}

/* Recording events
 ******************/
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag {
    NSLog(@"audioRecorderDidFinishRecording:%d", flag);
    [self _deactivateSession];
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"audioRecorderEncodeErrorDidOccur: %@", error);
}

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder {
    // e.g Phone call coming in
}

- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags {
    // Recording is available again
}

/* Playback events
 *****************/
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"audioPlayerDidFinishPlaying:%d", flag);
    [self _deactivateSession];
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    // e.g. Phone call coming in
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    // Playing is available again
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    NSLog(@"audioPlayerDecodeErrorDidOccur %@", error);
}

/* Misc
 ******/
- (AVAudioSession*)_activateSession:(NSString*)category options:(AVAudioSessionCategoryOptions)options {
    NSLog(@"Activating session");
    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSError* err;
//    AVAudioSessionCategoryOptions sessionOptions = AVAudioSessionCategoryOptionMixWithOthers;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
    if (err) {
        NSLog(@"ERROR setCategory:withOptions: %@", err);
        return nil;
    }
    [session setActive:YES error:&err];
    if (err) {
        NSLog(@"ERROR setActive: %@", err);
        return nil;
    }
    return session;
}

- (void)_deactivateSession {
    NSLog(@"Deactivating session");
    NSError* err;
    [[AVAudioSession sharedInstance] setActive:NO error:&err];
    if (err) {
        NSLog(@"Error deactivating session %@", err);
    }
}

+ (NSURL*) getFileLocation {
    return [BTAudio getFileLocation:@"audioRecording.m4a"];
}

+ (NSURL*) getFileLocation:(NSString*)filename {
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [[searchPaths lastObject] stringByAppendingPathComponent:filename];
    return [NSURL fileURLWithPath:documentPath];
}

@end
