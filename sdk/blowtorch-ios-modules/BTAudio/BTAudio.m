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

CFURLRef getFileUrl(NSString* filepath) {
    return CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge   CFStringRef)filepath, kCFURLPOSIXPathStyle, false);
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

BOOL setOutputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd) {
    return check(@"Set output stream format",
                 AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus, &asbd, sizeof(asbd)));
}
BOOL setInputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd) {
    return check(@"Set input stream format",
                 AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus, &asbd, sizeof(asbd)));
}
AudioStreamBasicDescription _getStreamFormat(AudioUnit unit, AudioUnitScope scope, AudioUnitElement bus) {
    AudioStreamBasicDescription streamFormat;
    memset(&streamFormat, 0, sizeof(streamFormat));
    UInt32 size = sizeof(streamFormat);
    check(@"Get stream format", AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, scope, bus, &streamFormat, &size));
    return streamFormat;
}
AudioStreamBasicDescription getInputStreamFormat(AudioUnit unit, AudioUnitElement bus) {
    return _getStreamFormat(unit, kAudioUnitScope_Input, bus);
}
AudioStreamBasicDescription getOutputStreamFormat(AudioUnit unit, AudioUnitElement bus) {
    return _getStreamFormat(unit, kAudioUnitScope_Output, bus);
}

OSStatus setPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitScope scope, AudioUnitElement element, UInt32 data) {
    OSStatus status = AudioUnitSetProperty(unit, propertyId, scope, element, &data, sizeof(data));
    check(@"setPropertyInt", status);
    return status;
}
OSStatus setInputPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitElement element, UInt32 data) {
    return setPropertyInt(unit, propertyId, kAudioUnitScope_Input, element, data);
}
OSStatus setOutputPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitElement element, UInt32 data) {
    return setPropertyInt(unit, propertyId, kAudioUnitScope_Output, element, data);
}

AudioComponentDescription getComponentDescription(OSType type, OSType subType) {
    AudioComponentDescription iOUnitDescription;
    iOUnitDescription.componentType = type;
    iOUnitDescription.componentSubType = subType;
    iOUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    iOUnitDescription.componentFlags = 0;
    iOUnitDescription.componentFlagsMask = 0;
    return iOUnitDescription;
}
AVAudioSession* createAudioSession(NSString* category) {
    NSError* err;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
    if (err) { NSLog(@"ERROR setCategory:withOptions: %@", err); return nil; }
    [session setActive:YES error:&err];
    if (err) { NSLog(@"ERROR setActive: %@", err); return nil; }
    return session;
}




@interface BTAudioGraph : NSObject
@property (nonatomic,assign,readonly) AUNode ioNode;
@property (nonatomic,assign,readonly) AudioUnit ioUnit;
- (void) readFile:(NSString*)filepath toNode:(AUNode)node bus:(AudioUnitElement)bus;
@end

@implementation BTAudioGraph {
    AUGraph _graph;
    ExtAudioFileRef _recordToAudioExtFileRef;
}
@synthesize ioNode=_ioNode, ioUnit=_ioUnit;
/* Initialize
 ************/
- (id) init {
    if (self = [super init]) {
        check(@"Create graph", NewAUGraph(&_graph));
        check(@"Open graph", AUGraphOpen(_graph));
        check(@"Init graph", AUGraphInitialize(_graph));
    }
    return self;
}
- (id) initWithSpeaker {
    if ([self init]) {
        _ioNode = [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO];
        _ioUnit = [self getUnit:_ioNode];
    }
    return self;
}
- (id) initWithSpeakerAndMicrophoneInput { // use voice for iPhone later
    if ([self init]) {
        _ioNode = [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO];
        _ioUnit = [self getUnit:_ioNode];
        check(@"Enable mic input", setInputPropertyInt([self getUnit:_ioNode], kAudioOutputUnitProperty_EnableIO, RIOInputFromMic, 1));
    }
    return self;
}
- (id) initWithSpearkAndVoiceInput {
    if ([self init]) {
        _ioNode = [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_VoiceProcessingIO];
        _ioUnit = [self getUnit:_ioNode];
        check(@"Enable mic input", setInputPropertyInt([self getUnit:_ioNode], kAudioOutputUnitProperty_EnableIO, RIOInputFromMic, 1));
    }
    return self;
}
- (id) initWithOfflineIO {
    if ([self init]) {
        _ioNode = [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_GenericOutput];
        _ioUnit = [self getUnit:_ioNode];
    }
    return self;
}

- (void)recordFromUnit:(AudioUnit)unit bus:(AudioUnitElement)bus toFile:(NSString *)filepath {
    AudioStreamBasicDescription destinationFormat;
    memset(&destinationFormat, 0, sizeof(destinationFormat));
    destinationFormat.mFormatID = kAudioFormatMPEG4AAC;
    destinationFormat.mChannelsPerFrame = 2;
    destinationFormat.mSampleRate = 16000.0;
    UInt32 size = sizeof(destinationFormat);
    OSStatus result = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destinationFormat);
    if(result) printf("AudioFormatGetProperty %ld \n", result);

    AudioStreamBasicDescription fileFormat = destinationFormat;
    check(@"ExtAudioFileCreateWithURL",
          ExtAudioFileCreateWithURL(getFileUrl(filepath), kAudioFileM4AType, &fileFormat, NULL, kAudioFileFlags_EraseFile, &_recordToAudioExtFileRef));
    
    UInt32 codec = kAppleHardwareAudioCodecManufacturer;
    check(@"Set codec", ExtAudioFileSetProperty(_recordToAudioExtFileRef, kExtAudioFileProperty_CodecManufacturer, sizeof(codec), &codec));
    
    AudioStreamBasicDescription unitFormat = getInputStreamFormat(unit, bus);
    check(@"Set format", ExtAudioFileSetProperty(_recordToAudioExtFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(unitFormat), &unitFormat));
    
    check(@"Erase file with first write", ExtAudioFileWriteAsync(_recordToAudioExtFileRef, 0, NULL));

    check(@"Set recording callback", AudioUnitAddRenderNotify(unit, recordFromUnitToFile, (__bridge void*)self));
}
static int count = 0;
static OSStatus recordFromUnitToFile (void *inRefCon, AudioUnitRenderActionFlags* ioActionFlags, const AudioTimeStamp* inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    if (*ioActionFlags != kAudioUnitRenderAction_PostRender) { return noErr; }
    
    OSStatus result;
    BTAudioGraph* THIS = (__bridge BTAudioGraph *)inRefCon;
    if (count < 200) {
        result =  ExtAudioFileWriteAsync(THIS->_recordToAudioExtFileRef, inNumberFrames, ioData);
        if(result) printf("ExtAudioFileWriteAsync %ld \n", result);
    }
    count += 1;
    if (count == 200) {
        result = ExtAudioFileDispose(THIS->_recordToAudioExtFileRef);
        if (result) printf("ExtAudioFileDispose %ld \n", result);
        printf("Closed file");
    }
    return noErr;
}


- (void) readFile:(NSString*)filepath toNode:(AUNode)node bus:(AudioUnitElement)bus {
    AUNode filePlayerNode = [self addNodeOfType:kAudioUnitType_Generator subType:kAudioUnitSubType_AudioFilePlayer];
    [self connectNode:filePlayerNode bus:0 toNode:node bus:bus]; // Node must be connected before priming the file unit player
    AudioUnit fileAU = [self getUnit:filePlayerNode];
    
    AudioFileID inputFile;
    check(@"Open audio file", AudioFileOpenURL(getFileUrl([BTFiles documentPath:@"audio.m4a"]), kAudioFileReadPermission, 0, &inputFile));
    
    AudioStreamBasicDescription inputFormat;
    UInt32 propSize = sizeof(inputFormat);
    check(@"Get audio file format", AudioFileGetProperty(inputFile, kAudioFilePropertyDataFormat, &propSize, &inputFormat));
    
    check(@"Set file player file id", AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &(inputFile), sizeof((inputFile))));
    
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    check(@"Get file audio packet count", AudioFileGetProperty(inputFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets));
    
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
}

/* Add, configure and connect nodes
 **********************************/
- (AUNode) addNodeOfType:(OSType)type subType:(OSType)subType {
    AUNode node;
    AudioComponentDescription componentDescription = getComponentDescription(type, subType);
    if (!check(@"Add node", AUGraphAddNode(_graph, &componentDescription, &node))) { return 0; }
    return node;
}
- (AudioUnit) getUnit:(AUNode)node {
    AudioUnit unit;
    if (!check(@"Get audio unit", AUGraphNodeInfo(_graph, node, NULL, &unit))) { return NULL; }
    return unit;
}
- (BOOL) connectNode:(AUNode)nodeA bus:(UInt32)busA toNode:(AUNode)nodeB bus:(UInt32)busB {
    return check(@"Connect nodes", AUGraphConnectNodeInput(_graph, nodeA, busA, nodeB, busB));
}
/* Start/stop audio flow
 ***********************/
- (BOOL) start {
    return check(@"Start graph", AUGraphStart(_graph));
}
- (BOOL) stop {
    Boolean isRunning = false;
    if (!check(@"Check if graph is running", AUGraphIsRunning(_graph, &isRunning))) { return NO; }
    return isRunning ? check(@"Stop graph", AUGraphStop(_graph)) : YES;
}
@end



@implementation BTAudio {
    AUGraph _graph;
    AVAudioSession* _session;
    ExtAudioFileRef extAudioFileRef;
    BTAudioGraph* _audioGraph;
}

static BTAudio* instance;

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    // Task 1: Record audio to file
    [app registerHandler:@"BTAudio.recordToFile" handler:^(id data, BTResponseCallback responseCallback) {
        
    }];
    // Task 2: Read audio from file, apply filter, output to speaker
    // Task 3: Read audio from file, apply filter, output to file
    // Task 4: Visualize audio in task 1 & 2
    
    if (RECORD) { [self recordToFile]; }
    else { [self playFromFile]; }
}

- (void) playFromFile {
    BTAudioGraph* graph = [[BTAudioGraph alloc] initWithSpeaker];
    [graph readFile:[BTFiles documentPath:@"audio.m4a"] toNode:graph.ioNode bus:RIOInputFromApp];
    [graph start];
}

static BOOL RECORD = NO;

- (void) recordToFile {
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
    
    [graph recordFromUnit:pitchUnit bus:0 toFile:[BTFiles documentPath:@"audio.m4a"]];

    [graph start];
}
@end






