//
//  BTAudio.m
//  dogo
//
//  Created by Marcus Westin on 1/10/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTAudio.h"
#import "BTAudioGraph.h"

/* Audio graph wrapper
 *********************/

/* BTAudio
 *********/
@implementation BTAudio {
    AUGraph _graph;
    AVAudioSession* _session;
    ExtAudioFileRef extAudioFileRef;
    BTAudioGraph* _audioGraph;
}

static BTAudio* instance;

static BOOL RECORD = NO;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    // Task 1: Record audio to file
    [app registerHandler:@"BTAudio.recordFromMicrophoneToFile" handler:^(id data, BTResponseCallback responseCallback) {
        [self recordFromMicrophoneToFile:data responseCallback:responseCallback];
    }];
    // Task 2: Read audio from file, apply filter, output to speaker
    [app registerHandler:@"BTAudio.playFromFileToSpeaker" handler:^(id data, BTResponseCallback responseCallback) {
        [self playFromFileToSpeaker:data responseCallback:responseCallback];
    }];
    // Task 3: Read audio from file, apply filter, output to file
    // Task 4: Visualize audio in task 1 & 2
    
    if (RECORD) {
        [self recordFromMicrophoneToFile:@{@"document":@"audio.m4a"} responseCallback:^(id error, id responseData) {
            NSLog(@"Recording %@ %@", error, responseData);
        }];
    } else {
        [self playFromFileToSpeaker:@{@"document":@"audio.m4a"} responseCallback:^(id error, id responseData) {
            NSLog(@"Playing %@ %@", error, responseData);
        }];
    }
}

- (void) playFromFileToSpeaker:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback {
    BTAudioGraph* graph = [[BTAudioGraph alloc] initWithSpeaker];
    [graph readFile:[BTFiles documentPath:data[@"document"]] toNode:graph.ioNode bus:RIOInputFromApp];
    [graph start];
    responseCallback(nil,nil);
}

- (void) recordFromMicrophoneToFile:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback {
    _session = createAudioSession(AVAudioSessionCategoryPlayAndRecord);
    if (!_session.inputAvailable) { NSLog(@"WARNING Requested input is not available");}
    
    BTAudioGraph* graph = _audioGraph = [[BTAudioGraph alloc] initWithSpeakerAndMicrophoneInput];
    
    AUNode pitchNode = [graph addNodeOfType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_NewTimePitch];
    AudioUnit pitchUnit = [graph getUnit:pitchNode];
    check(@"Set pitch", AudioUnitSetParameter(pitchUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, 800, 0)); // -2400 to 2400
    
    AudioStreamBasicDescription pitchStreamFormat = getInputStreamFormat(pitchUnit, 0);
    // Microphone -> Pitchshift
    setOutputStreamFormat(graph.ioUnit, RIOOutputToApp, pitchStreamFormat);
    [graph connectNode:graph.ioNode bus:RIOOutputToApp toNode:pitchNode bus:0];
    
    // Pitchshift -> Speaker
    setInputStreamFormat(graph.ioUnit, RIOInputFromApp, pitchStreamFormat);
    [graph connectNode:pitchNode bus:0 toNode:graph.ioNode bus:RIOInputFromApp];
    
    [graph recordFromUnit:pitchUnit bus:0 toFile:[BTFiles documentPath:data[@"document"]]];
    
    [graph start];

    responseCallback(nil, nil);
}
@end






