//
//  BTAudio.m
//  dogo
//
//  Created by Marcus Westin on 1/10/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTAudio.h"
#import "BTNet.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "BTFiles.h"

@implementation BTAudio {
    AVAudioRecorder* _recorder;
    AVAudioPlayer* _player;
    
    AUGraph _graph;
    AUNode _ioNode;
    AudioUnit _ioUnit;
    AVAudioSession* _session;
    
    ExtAudioFileRef extAudioFileRef;
}

static BTAudio* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    // Task 1: Record audio to file
    // Task 2: Read audio from file, apply filter, output to speaker
    // Task 3: Read audio from file, apply filter, output to file
    // Task 4: Visualize audio in task 1 & 2
    
    if (RECORD) { [self recordToFile]; }
    else { [self playFromFile]; }
}

- (void) playFromFile {
    {
        [self createAndOpenAndInitializeGraph];
    }
    
    AUNode rioNode = [self setMicrophoneIoNode];
    AUNode filePlayerNode = [self addNodeOfType:kAudioUnitType_Generator subType:kAudioUnitSubType_AudioFilePlayer];

    [self connectNode:filePlayerNode bus:0 toNode:rioNode bus:RIOInputFromApp];
    
    {
        AudioFileID inputFile; // reference to your input file
        
        // open the input audio file and store the AU ref in _player
        check(@"Open audio file",
              AudioFileOpenURL(getFileUrl(@"audio.m4a"), kAudioFileReadPermission, 0, &inputFile));
        
        // get the reference to the AudioUnit object for the file player graph node
        AudioUnit fileAU = [self getUnit:filePlayerNode];

        AudioStreamBasicDescription inputFormat;
        UInt32 propSize = sizeof(inputFormat);
        check(@"Get audio file format",
              AudioFileGetProperty(inputFile, kAudioFilePropertyDataFormat, &propSize, &inputFormat));
        
        check(@"Set file player file id",
              AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &(inputFile), sizeof((inputFile))));
        
        UInt64 nPackets;
        UInt32 propsize = sizeof(nPackets);
        check(@"Get file audio packet count",
              AudioFileGetProperty(inputFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets));
        
        // tell the file player AU to play the entire file
        ScheduledAudioFileRegion rgn;
        memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
        rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
        rgn.mTimeStamp.mSampleTime = 0;
        rgn.mCompletionProc = NULL;
        rgn.mCompletionProcUserData = NULL;
        rgn.mAudioFile = inputFile;
        rgn.mLoopCount = 0;
        rgn.mStartFrame = 0;
        rgn.mFramesToPlay = nPackets * inputFormat.mFramesPerPacket;
        
        check(@"Set audio player file region",
              AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0,&rgn, sizeof(rgn)));
        
        // prime the file player AU with default values
        UInt32 defaultVal = 0;
        check(@"Prime the file player unit (???)",
              AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal)));
        
        // tell the file player AU when to start playing (-1 sample time means next render cycle)
        AudioTimeStamp startTime;
        memset (&startTime, 0, sizeof(startTime));
        startTime.mFlags = kAudioTimeStampSampleTimeValid;
        startTime.mSampleTime = -1;
        check(@"Set audio player file start timestamp",
              AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)));
        
        // file duration
        //double duration = (nPackets * _player.inputFormat.mFramesPerPacket) / _player.inputFormat.mSampleRate;
    }
    
    [self startGraph];
}

static BOOL RECORD = NO;

- (void) recordToFile {
    [self createSessionForPlayAndRecord];
    [self createAndOpenAndInitializeGraph];

    if (!_session.inputAvailable) { NSLog(@"WARNING Requested input is not available");}

    AUNode rioNode = [self setMicrophoneIoNode]; // setVoiceIoNode for iPhone
    AudioUnit rioUnit = [self getUnit:rioNode];
    check(@"Enable mic input",
          setInputPropertyInt(rioUnit, kAudioOutputUnitProperty_EnableIO, RIOInputFromMic, 1));
    
    AUNode pitchNode = [self addNodeOfType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_NewTimePitch];
    AudioUnit pitchUnit = [self getUnit:pitchNode];
    check(@"Set pitch",
          AudioUnitSetParameter(pitchUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, 800, 0)); // -2400 to 2400
    
    AudioStreamBasicDescription pitchStreamFormat = getInputStreamFormat(pitchUnit, 0);
    
    // Microphone -> Pitchshift
    setOutputStreamFormat(rioUnit, RIOOutputToApp, pitchStreamFormat);
    [self connectNode:rioNode bus:RIOOutputToApp toNode:pitchNode bus:0];

    // Pitchshift -> Speaker
    setInputStreamFormat(rioUnit, RIOInputFromApp, pitchStreamFormat);
    [self connectNode:pitchNode bus:0 toNode:rioNode bus:RIOInputFromApp];
    
    {
        AudioStreamBasicDescription fileFormat = getFileFormat();
        check(@"ExtAudioFileCreateWithURL",
              ExtAudioFileCreateWithURL(getFileUrl(@"audio.m4a"), kAudioFileM4AType, &fileFormat, NULL, kAudioFileFlags_EraseFile, &extAudioFileRef));
        
        // specify codec
        UInt32 codec = kAppleHardwareAudioCodecManufacturer;
        check(@"ExtAudioFileSetProperty",
              ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_CodecManufacturer, sizeof(codec), &codec));
        
        check(@"ExtAudioFileSetProperty",
              ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(pitchStreamFormat), &pitchStreamFormat));
        
        check(@"ExtAudioFileWriteAsync",
              ExtAudioFileWriteAsync(extAudioFileRef, 0, NULL));
        
        check(@"AudioUnitAddRenderNotify",
              AudioUnitAddRenderNotify(pitchUnit, renderCallback, (__bridge void*)self));
    }

    [self startGraph];
}

CFURLRef getFileUrl(NSString* filename) {
    return CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge   CFStringRef)[BTFiles documentPath:filename], kCFURLPOSIXPathStyle, false);
}

AudioStreamBasicDescription getFileFormat() {
    AudioStreamBasicDescription destinationFormat;
    memset(&destinationFormat, 0, sizeof(destinationFormat));
    destinationFormat.mFormatID = kAudioFormatMPEG4AAC;
    destinationFormat.mChannelsPerFrame = 2;
    destinationFormat.mSampleRate = 16000.0;
    UInt32 size = sizeof(destinationFormat);
    OSStatus result = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destinationFormat);
    if(result) printf("AudioFormatGetProperty %ld \n", result);
    return destinationFormat;
}

static int count = 0;

static OSStatus renderCallback (void *inRefCon, AudioUnitRenderActionFlags* ioActionFlags, const AudioTimeStamp* inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    if (*ioActionFlags != kAudioUnitRenderAction_PostRender) { return noErr; }
    
    OSStatus result;
    BTAudio* THIS = (__bridge BTAudio *)inRefCon;
    if (count < 200) {
        result =  ExtAudioFileWriteAsync(THIS->extAudioFileRef, inNumberFrames, ioData);
        if(result) printf("ExtAudioFileWriteAsync %ld \n", result);
    }
    count += 1;
    if (count == 200) {
        result = ExtAudioFileDispose(THIS->extAudioFileRef);
        if (result) printf("ExtAudioFileDispose %ld \n", result);
        printf("Closed file");
    }
    return noErr;
}





/* Graph creation & configuration
 ********************************/
// 0) Create an audio session
- (BOOL) createSessionForSilencableSounds { return [self _createSession:AVAudioSessionCategorySoloAmbient]; }
- (BOOL) createSessionForContinuousPlayback { return [self _createSession:AVAudioSessionCategoryPlayback]; }
- (BOOL) createSessionForRecording { return [self _createSession:AVAudioSessionCategoryRecord]; }
- (BOOL) createSessionForPlayAndRecord { return [self _createSession:AVAudioSessionCategoryPlayAndRecord]; }
- (BOOL) _createSession:(NSString*)category {
    NSError* err;
    _session = [AVAudioSession sharedInstance];
    [_session setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
    if (err) { NSLog(@"ERROR setCategory:withOptions: %@", err); return NO; }
    [_session setActive:YES error:&err];
    if (err) { NSLog(@"ERROR setActive: %@", err); return NO; }
    return !!_session;
}

// 1) Create graph
- (BOOL) createAndOpenAndInitializeGraph {
    return check(@"Create graph", NewAUGraph(&_graph)) && check(@"Open graph", AUGraphOpen(_graph)) && check(@"Init graph", AUGraphInitialize(_graph));
}

// 2) Create IO node
- (AUNode) setMicrophoneIoNode {
    return [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO];
}
- (AUNode) setVoiceIoNode {
    return [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_VoiceProcessingIO];
}

// 3) Create other nodes
- (AUNode) addNodeOfType:(OSType)type subType:(OSType)subType {
    AUNode node;
    AudioComponentDescription componentDescription = _getComponentDescription(type, subType);
    if (!check(@"Add node", AUGraphAddNode(_graph, &componentDescription, &node))) { return 0; }
    return node;
}
AudioComponentDescription _getComponentDescription(OSType type, OSType subType) {
    AudioComponentDescription iOUnitDescription;
    iOUnitDescription.componentType = type;
    iOUnitDescription.componentSubType = subType;
    iOUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    iOUnitDescription.componentFlags = 0;
    iOUnitDescription.componentFlagsMask = 0;
    return iOUnitDescription;
}

// 4) Configure node audio units
- (AudioUnit) getUnit:(AUNode)node {
    AudioUnit unit;
    if (!check(@"Get audio unit", AUGraphNodeInfo(_graph, node, NULL, &unit))) { return NULL; }
    return unit;
}

// 5) Connect nodes in the graph
- (BOOL) connectNode:(AUNode)nodeA bus:(UInt32)busA toNode:(AUNode)nodeB bus:(UInt32)busB {
    return check(@"Connect nodes", AUGraphConnectNodeInput(_graph, nodeA, busA, nodeB, busB));
}


// 6) Start and stop audio flow
- (BOOL) startGraph {
    return check(@"Start graph", AUGraphStart(_graph));
}
- (BOOL) stopGraph {
    Boolean isRunning = false;
    if (!check(@"Check if graph is running", AUGraphIsRunning(_graph, &isRunning))) { return NO; }
    return isRunning ? check(@"Stop graph", AUGraphStop(_graph)) : YES;
}



/* Utilities
 ***********/

//                          -------------------------
//                          | i                   o |
// -- BUS 1 -- from mic --> | n    REMOTE I/O     u | -- BUS 1 -- to app -->
//                          | p      AUDIO        t |
// -- BUS 0 -- from app --> | u       UNIT        p | -- BUS 0 -- to speaker -->
//                          | t                   u |
//                          |                     t |
//                          -------------------------
const AudioUnitElement RIOInputFromMic = 1;
const AudioUnitElement RIOInputFromApp = 0;
const AudioUnitElement RIOOutputToSpeaker = 0;
const AudioUnitElement RIOOutputToApp = 1;

BOOL setOutputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd) {
    return check(@"Set output stream format",
                 AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus, &asbd, sizeof(asbd)));
}
BOOL setInputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd) {
    return check(@"Set input stream format",
                 AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus, &asbd, sizeof(asbd)));
}
AudioStreamBasicDescription getInputStreamFormat(AudioUnit unit, AudioUnitElement bus) {
    return _getStreamFormat(unit, kAudioUnitScope_Input, bus);
}
AudioStreamBasicDescription getOutputStreamFormat(AudioUnit unit, AudioUnitElement bus) {
    return _getStreamFormat(unit, kAudioUnitScope_Output, bus);
}
AudioStreamBasicDescription _getStreamFormat(AudioUnit unit, AudioUnitScope scope, AudioUnitElement bus) {
    AudioStreamBasicDescription streamFormat;
    memset(&streamFormat, 0, sizeof(streamFormat));
    UInt32 size = sizeof(streamFormat);
    check(@"Get stream format", AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, scope, bus, &streamFormat, &size));
    return streamFormat;
}

OSStatus setInputPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitElement element, UInt32 data) {
    return setPropertyInt(unit, propertyId, kAudioUnitScope_Input, element, data);
}
OSStatus setOutputPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitElement element, UInt32 data) {
    return setPropertyInt(unit, propertyId, kAudioUnitScope_Output, element, data);
}
OSStatus setPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitScope scope, AudioUnitElement element, UInt32 data) {
    OSStatus status = AudioUnitSetProperty(unit, propertyId, scope, element, &data, sizeof(data));
    check(@"setPropertyInt", status);
    return status;
}

void error(NSString* errorString, OSStatus status) {
    char str[20];
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(status);
    
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) { // is it a 4-char-code?
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else { // no, format as an integer
		sprintf(str, "%d", (int)status);
    }
    NSLog(@"*** %@ error: %s\n", errorString, str);
}

BOOL check(NSString* str, OSStatus status) {
    if (status != noErr) { error(str, status); }
    return status == noErr;
}
@end






