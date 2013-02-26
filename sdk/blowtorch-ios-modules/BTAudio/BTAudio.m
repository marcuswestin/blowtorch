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
    [app registerHandler:@"BTAufio.readFromFileToFile" handler:^(id data, BTResponseCallback responseCallback) {
        [self readFromFileToFile:data responseCallback:responseCallback];
    }];
    
    if (RECORD) {
        [self recordFromMicrophoneToFile:@{@"document":@"audio.m4a"} responseCallback:^(id error, id responseData) {
            NSLog(@"Recording %@ %@", error, responseData);
        }];
    } else {
        [self playFromFileToSpeaker:@{@"document":@"audio.m4a"} responseCallback:^(id error, id responseData) {
            NSLog(@"Playing %@ %@", error, responseData);
        }];
    }
    
    /*
     
     http://developer.apple.com/library/ios/#documentation/AudioUnit/Reference/AUComponentServicesReference/Reference/reference.html#//apple_ref/c/econst/kAudioUnitSubType_GenericOutput
     
     Audio Unit types
     kAudioUnitType_Output            = 'auou',
     kAudioUnitType_MusicDevice       = 'aumu',
     kAudioUnitType_MusicEffect       = 'aumf',
     kAudioUnitType_FormatConverter   = 'aufc',
     kAudioUnitType_Effect            = 'aufx',
     kAudioUnitType_Mixer             = 'aumx',
     kAudioUnitType_Panner            = 'aupn',
     kAudioUnitType_OfflineEffect     = 'auol',
     kAudioUnitType_Generator         = 'augn',

     
     Audio Unit Parameter Event Types
     kParameterEvent_Immediate = 1,
     kParameterEvent_Ramped    = 2
     
     
     Converter Audio Unit Subtypes
     
     kAudioUnitSubType_AUConverter        = 'conv', linear PCM conversions, such as changes to sample rate, bit depth, or interleaving.
   ! kAudioUnitSubType_NewTimePitch       = 'nutp', independent control of both playback rate and pitch.
   ! kAudioUnitSubType_TimePitch          = 'tmpt', independent control of playback rate and pitch
     kAudioUnitSubType_DeferredRenderer   = 'defr', acquires audio input from a separate thread than the thread on which its render method is called
     kAudioUnitSubType_Splitter           = 'splt', duplicates the input signal to each of its two output buses.
     kAudioUnitSubType_Merger             = 'merg', merges the two input signals to the single output.
   ! kAudioUnitSubType_Varispeed          = 'vari', control playback rate. As the playback rate increases, so does pitch.
   ! kAudioUnitSubType_AUiPodTime         = 'iptm', simple, limited control over playback rate and time.
     kAudioUnitSubType_AUiPodTimeOther    = 'ipto'  ???
     
     
     Effect Audio Unit Subtypes
     
     kAudioUnitSubType_PeakLimiter          = 'lmtr', enforces an upper dynamic limit on an audio signal.
     kAudioUnitSubType_DynamicsProcessor    = 'dcmp', provides dynamic compression or expansion.
   ! kAudioUnitSubType_Reverb2              = 'rvb2', reverb unit for iOS.
     kAudioUnitSubType_LowPassFilter        = 'lpas', cuts out frequencies below a specified cutoff
     kAudioUnitSubType_HighPassFilter       = 'hpas', cuts out frequencies above a specified cutoff
     kAudioUnitSubType_BandPassFilter       = 'bpas', cuts out frequencies outside specified upper and lower cutoffs
     kAudioUnitSubType_HighShelfFilter      = 'hshf', suitable for implementing a treble control in an audio playback or recording system.
     kAudioUnitSubType_LowShelfFilter       = 'lshf', suitable for implementing a bass control in an audio playback or recording system.
     kAudioUnitSubType_ParametricEQ         = 'pmeq', a filter whose center frequency, boost/cut level, and Q can be adjusted.
   ! kAudioUnitSubType_Delay                = 'dely', introduces a time delay to a signal.
   ! kAudioUnitSubType_Distortion           = 'dist', provides a distortion effect.
     kAudioUnitSubType_AUiPodEQ             = 'ipeq', provides a graphic equalizer in iPhone OS.
     kAudioUnitSubType_NBandEQ              = 'nbeq'  multi-band equalizer with specifiable filter type for each band.

     
     Mixer Audio Unit Subtypes
     
   ! kAudioUnitSubType_MultiChannelMixer      = 'mcmx', multiple input buses, one output bus always with two channels.
     kAudioUnitSubType_MatrixMixer            = 'mxmx', like MultiChannelMixer but configurable mixing
     kAudioUnitSubType_AU3DMixerEmbedded      = '3dem', 3D stuff
     
     
     Generator Audio Unit Subtypes
     
     kAudioUnitSubType_ScheduledSoundPlayer  = 'sspl', schedule slices of audio to be played at specified times.
   ! kAudioUnitSubType_AudioFilePlayer       = 'afpl', play a file.
     */
}

- (void) readFromFileToFile:(NSDictionary*)data responseCallback:(BTResponseCallback)responseCallback {
    BTAudioGraph* graph = [[BTAudioGraph alloc] initWithOfflineIO];
    
    [graph readFile:[BTFiles documentPath:@"fromDocument"] toNode:graph.ioNode bus:RIOInputFromApp];
}

- (AUNode) addPitchNodeToGraph:(BTAudioGraph*)graph andConnectFromNode:(AUNode)node bus:(AudioUnitElement)bus  {
    AUNode pitchNode = [graph addNodeNamed:@"pitch" type:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_NewTimePitch];
    AudioUnit pitchUnit = [graph getUnit:pitchNode];
    AudioStreamBasicDescription pitchStreamFormat = getInputStreamFormat(pitchUnit, 0);
    setOutputStreamFormat(graph.ioUnit, RIOOutputToApp, pitchStreamFormat);
    [graph connectNode:node bus:bus toNode:pitchNode bus:0];
    return pitchNode;
}

- (void) setPitch:(float)pitch forGraph:(BTAudioGraph*)graph {
    AudioUnit unit = [graph getUnitNamed:@"pitch"];
    check(@"Set pitch", AudioUnitSetParameter(unit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, 800, 0)); // -2400 to 2400
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
    
    // Add pitch node
    AUNode pitchNode = [self addPitchNodeToGraph:graph andConnectFromNode:graph.ioNode bus:RIOOutputToApp];
    AudioUnit pitchUnit = [graph getUnit:pitchNode];
    AudioStreamBasicDescription pitchStreamFormat = getInputStreamFormat(pitchUnit, 0);
    
    // Pitch -> Speaker
    setInputStreamFormat(graph.ioUnit, RIOInputFromApp, pitchStreamFormat);
    [graph connectNode:pitchNode bus:0 toNode:graph.ioNode bus:RIOInputFromApp];
    
    [graph recordFromUnit:pitchUnit bus:0 toFile:[BTFiles documentPath:data[@"document"]]];
    [graph start];

    responseCallback(nil, nil);
}
@end






