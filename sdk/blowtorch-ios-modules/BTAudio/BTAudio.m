//
//  BTAudio.m
//  dogo
//
//  Created by Marcus Westin on 1/10/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTAudio.h"
#import "BTAudioGraph.h"
#include <mach/mach_time.h>

/* Audio graph wrapper
 *********************/

@interface BTAUdioEnpoints : NSObject
@property (assign,readonly) AUNode firstNode;
@property (assign,readonly) AUNode lastNode;
@property (readonly) AudioUnit firstUnit;
@property (readonly) AudioUnit lastUnit;
@property (readonly) AudioStreamBasicDescription lastFormat;
@property (readonly) AudioStreamBasicDescription firstFormat;
@end
@implementation BTAUdioEnpoints {
    BTAudioGraph* _graph;
}
@synthesize firstNode=_firstNode, lastNode=_lastNode;
- (id) initWithGraph:(BTAudioGraph*)graph firstNode:(AUNode)firstNode lastNode:(AUNode)lastNode {
    if (self = [super init]) {
        _graph = graph;
        _firstNode = firstNode;
        _lastNode = lastNode;
    }
    return self;
}
- (AudioUnit) firstUnit { return [_graph getUnit:_firstNode]; }
- (AudioUnit) lastUnit { return [_graph getUnit:_lastNode]; }
- (AudioStreamBasicDescription) firstFormat { return getInputStreamFormat(self.firstUnit, 0); }
- (AudioStreamBasicDescription) lastFormat { return getOutputStreamFormat(self.lastUnit, 0); }

@end

/* BTAudio
 *********/
@implementation BTAudio {
    AVAudioSession* _session;
    BTAudioGraph* _graph;
}

static BTAudio* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    // Task 1: Record audio to file
    [app handleCommand:@"BTAudio.recordFromMicrophoneToFile" handler:^(id data, BTCallback responseCallback) {
        [self recordFromMicrophoneToFile:data responseCallback:responseCallback];
    }];
    [app handleCommand:@"BTAudio.stopRecordingFromMicrophoneToFile" handler:^(id data, BTCallback responseCallback) {
        [self stopRecordingFromMicrophoneToFile:data responseCallback:responseCallback];
    }];
    // Task 2: Read audio from file, apply filter, output to speaker
    [app handleCommand:@"BTAudio.playFromFileToSpeaker" handler:^(id data, BTCallback responseCallback) {
        [self playFromFileToSpeaker:data responseCallback:responseCallback];
    }];
    // Task 3: Read audio from file, apply filter, output to file
    [app handleCommand:@"BTAudio.readFromFileToFile" handler:^(id data, BTCallback responseCallback) {
        [self readFromFileToFile:data responseCallback:responseCallback];
    }];
    // Misc: Set pitch
    [app handleCommand:@"BTAudio.setPitch" handler:^(id data, BTCallback responseCallback) {
        [self setPitch:data];
        responseCallback(nil,nil);
    }];

    /*
     
     Audio Unit types
     http://developer.apple.com/library/ios/#documentation/AudioUnit/Reference/AudioUnitParametersReference/Reference/reference.html
     
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
     
     
     Audio Unit Parameters:
     http://developer.apple.com/library/ios/#documentation/AudioUnit/Reference/AudioUnitPropertiesReference/Reference/reference.html
     
     */
}


- (void) readFromFileToFile:(NSDictionary*)data responseCallback:(BTCallback)responseCallback {
    BTAudioGraph* graph = _graph = [[BTAudioGraph alloc] initWithNoIO];
    BTAUdioEnpoints* endpoints = [self addEffectChain:graph];
    
    [self setPitch:data];
    
    // Read from file
    FileInfo* fileInfo = [graph readFile:[BTFiles documentPath:data[@"fromDocument"]] toNode:endpoints.firstNode bus:0];
    setOutputStreamFormat([graph getUnit:fileInfo.fileNode], 0, endpoints.firstFormat);
    // Write to file
    [graph recordFromNode:[graph getNodeNamed:@"record"] bus:0 toFile:[BTFiles documentPath:data[@"toDocument"]]];

    // Render the audio until done (this is instead of the typical [graph start])
    AudioUnitRenderActionFlags flags = kAudioOfflineUnitRenderAction_Render;
    AudioBufferList bufferList;
    UInt32 numFrames = fileInfo.fileFormat.mFramesPerPacket * fileInfo.numPackets;
    UInt32 framesPerBuffer = 1024;
    bufferList.mNumberBuffers = endpoints.lastFormat.mChannelsPerFrame;
    for (int i=0; i<endpoints.lastFormat.mChannelsPerFrame; i++) {
        bufferList.mBuffers[i].mNumberChannels = 1;
        bufferList.mBuffers[i].mDataByteSize = framesPerBuffer * endpoints.lastFormat.mBytesPerFrame;
        bufferList.mBuffers[i].mData = NULL;
    }
    for (UInt32 i=0; i*framesPerBuffer<=numFrames; i++) {
        AudioTimeStamp audioTimeStamp = {0};
        memset (&audioTimeStamp, 0, sizeof(audioTimeStamp));
        audioTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
        audioTimeStamp.mSampleTime = i * framesPerBuffer;
        check(@"Render audio",
              AudioUnitRender(endpoints.lastUnit, &flags, &audioTimeStamp, 0, framesPerBuffer, &bufferList));
    }
    [graph cleanupRecording];

    int duration = (numFrames / fileInfo.fileFormat.mSampleRate * 1000);
    responseCallback(nil,@{ @"duration":[NSNumber numberWithFloat:duration] });
}

- (void) playFromFileToSpeaker:(NSDictionary*)data responseCallback:(BTCallback)responseCallback {
    BTAudioGraph* graph = _graph = [[BTAudioGraph alloc] initWithSpeaker];
    BTAUdioEnpoints* endpoints = [self addEffectChain:graph];
    
    [self setPitch:data];
    
    // Read from file
    FileInfo* fileInfo = [graph readFile:[BTFiles documentPath:data[@"document"]] toNode:endpoints.firstNode bus:0];
    setOutputStreamFormat([graph getUnit:fileInfo.fileNode], 0, endpoints.firstFormat);
    // Write to speaker
    setInputStreamFormat(graph.ioUnit, RIOInputFromApp, endpoints.lastFormat);
    [graph connectNode:endpoints.lastNode bus:0 toNode:graph.ioNode bus:RIOInputFromApp];

    [graph start];
    responseCallback(nil,nil);
}

- (void) recordFromMicrophoneToFile:(NSDictionary*)data responseCallback:(BTCallback)responseCallback {
    _session = createAudioSession(AVAudioSessionCategoryPlayAndRecord);
    if (!_session.inputAvailable) { NSLog(@"WARNING Requested input is not available");}
    BTAudioGraph* graph = _graph = [[BTAudioGraph alloc] initWithSpeakerAndMicrophoneInput];
    BTAUdioEnpoints* endpoints = [self addEffectChain:graph];
    
    // Read from mic
    setOutputStreamFormat(graph.ioUnit, RIOOutputToApp, endpoints.firstFormat);
    [graph connectNode:graph.ioNode bus:RIOOutputToApp toNode:endpoints.firstNode bus:0];
    // Write to file
    [graph recordFromNode:[graph getNodeNamed:@"record"] bus:0 toFile:[BTFiles documentPath:data[@"document"]]];
    // Connect to speaker for IO pull, but set volume to 0
    [graph connectNode:endpoints.lastNode bus:0 toNode:graph.ioNode bus:RIOInputFromApp];
    setInputStreamFormat(graph.ioUnit, RIOInputFromApp, endpoints.lastFormat);
    [self setVolume:0];

    [graph start];
    responseCallback(nil, nil);
}
- (void) stopRecordingFromMicrophoneToFile:(NSDictionary*)data responseCallback:(BTCallback)responseCallback {
    [_graph stopRecordingToFileAndScheduleStop];
    responseCallback(nil,nil);
}

//////////////////
- (BTAUdioEnpoints*) addEffectChain:(BTAudioGraph*)graph {
    // Create pitch node
    AUNode pitchNode = [graph addNodeNamed:@"pitch" type:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_NewTimePitch];
    AudioUnit pitchUnit = [graph getUnit:pitchNode];
    // Create recording node
    AUNode recordNode = [graph addNodeNamed:@"record" type:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];
    AudioUnit recordUnit = [graph getUnit:recordNode];
    // Create volume node
    AUNode volumeNode = [graph addNodeNamed:@"volume" type:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];
    AudioUnit volumeUnit = [graph getUnit:volumeNode];

    // Connect pitch node -> record node -> volume node
    setInputStreamFormat(recordUnit, 0, getOutputStreamFormat(pitchUnit, 0));
    [graph connectNode:pitchNode bus:0 toNode:recordNode bus:0];
    setInputStreamFormat(volumeUnit, 0, getOutputStreamFormat(recordUnit, 0));
    [graph connectNode:recordNode bus:0 toNode:volumeNode bus:0];

    return [[BTAUdioEnpoints alloc] initWithGraph:graph firstNode:pitchNode lastNode:volumeNode];
}

- (void) setVolume:(NSNumber*)volumeFraction { // 0 - 1
    AudioUnit unit = [_graph getUnitNamed:@"volume"];
    AudioUnitSetParameter(unit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, [volumeFraction floatValue], 0);
}

- (void) setPitch:(NSDictionary*)data {
    if (!data[@"pitch"]) { return; }
    AudioUnit unit = [_graph getUnitNamed:@"pitch"];
    float pitch = [data[@"pitch"] floatValue] * 2400; // [-1,1] -> [-2400,2400]
    check(@"Set pitch", AudioUnitSetParameter(unit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0));
}

@end






