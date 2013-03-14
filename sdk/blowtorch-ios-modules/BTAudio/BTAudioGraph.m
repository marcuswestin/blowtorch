//
//  BTAudioGraph.m
//  dogo
//
//  Created by Marcus Westin on 2/25/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTAudioGraph.h"

@implementation FileInfo
@synthesize fileFormat=_fileFormat, numPackets=_numPackets, fileNode=_fileNode;
-(id)initWithFileFormat:(AudioStreamBasicDescription)fileFormat numPackets:(UInt64)numPackets fileNode:(AUNode)fileNode {
    _fileFormat = fileFormat;
    _numPackets = numPackets;
    _fileNode = fileNode;
    return self;
}
@end

@implementation BTAudioGraph {
    AUGraph _graph;
    ExtAudioFileRef _recordToAudioExtFileRef;
    NSMutableDictionary* _nodes;
    BOOL _recording;
    // Volume monitoring
    NSTimer* _volumeMeterTimer;
    Float32 _lastDbLevel;
}
@synthesize ioNode=_ioNode, ioUnit=_ioUnit;
/* Initialize
 ************/
- (id) init {
    if (self = [super init]) {
        check(@"Create graph", NewAUGraph(&_graph));
        check(@"Open graph", AUGraphOpen(_graph));
        check(@"Init graph", AUGraphInitialize(_graph));
        _nodes = [NSMutableDictionary dictionary];
        _recording = NO;
    }
    return self;
}
- (id) initWithSpeaker {
    if ([self init]) {
        _ioNode = [self addNodeNamed:@"io" type:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO];
        _ioUnit = [self getUnit:_ioNode];
    }
    return self;
}
- (id) initWithSpeakerAndMicrophoneInput { // use voice for iPhone later
    if ([self init]) {
        _ioNode = [self addNodeNamed:@"io" type:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO];
        _ioUnit = [self getUnit:_ioNode];
        check(@"Enable mic input", setInputPropertyInt([self getUnit:_ioNode], kAudioOutputUnitProperty_EnableIO, RIOInputFromMic, 1));
    }
    return self;
}
- (id) initWithSpearkAndVoiceInput {
    if ([self init]) {
        _ioNode = [self addNodeNamed:@"io" type:kAudioUnitType_Output subType:kAudioUnitSubType_VoiceProcessingIO];
        _ioUnit = [self getUnit:_ioNode];
        check(@"Enable mic input", setInputPropertyInt([self getUnit:_ioNode], kAudioOutputUnitProperty_EnableIO, RIOInputFromMic, 1));
    }
    return self;
}
- (id) initWithOfflineIO {
    if ([self init]) {
        _ioNode = [self addNodeNamed:@"io" type:kAudioUnitType_Output subType:kAudioUnitSubType_GenericOutput];
        _ioUnit = [self getUnit:_ioNode];
    }
    return self;
}
- (id) initWithNoIO {
    return [self init];
}

/* Add, configure and connect nodes
 **********************************/
- (AUNode) addNodeNamed:(NSString*)nodeName type:(OSType)type subType:(OSType)subType {
    AUNode node;
    AudioComponentDescription componentDescription = getComponentDescription(type, subType);
    if (!check(@"Add node", AUGraphAddNode(_graph, &componentDescription, &node))) { return 0; }
    _nodes[nodeName] = [NSNumber numberWithInt:node];
    return node;
}
- (AUNode)getNodeNamed:(NSString *)nodeName {
    AUNode node = [_nodes[nodeName] intValue];
    return node;
}
- (AudioUnit) getUnitNamed:(NSString*)nodeName {
    return [self getUnit:[self getNodeNamed:nodeName]];
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
    if (_volumeMeterTimer) {
        [_volumeMeterTimer invalidate];
        _volumeMeterTimer = nil;
    }
    Boolean isRunning = false;
    if (!check(@"Check if graph is running", AUGraphIsRunning(_graph, &isRunning))) { return NO; }
    return isRunning ? check(@"Stop graph", AUGraphStop(_graph)) : YES;
}

/* Helpers for advanced audio units
 **********************************/
- (void)recordFromNode:(AUNode)node bus:(AudioUnitElement)bus toFile:(NSString *)filepath {
    AudioUnit unit = [self getUnit:node];
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
    
    AudioStreamBasicDescription unitFormat = getOutputStreamFormat(unit, bus);
    check(@"Set format", ExtAudioFileSetProperty(_recordToAudioExtFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(unitFormat), &unitFormat));
    
    check(@"Erase file with first write", ExtAudioFileWriteAsync(_recordToAudioExtFileRef, 0, NULL));
    
    _recording = YES;
    check(@"Set recording callback", AudioUnitAddRenderNotify(unit, recordFromUnitToFile, (__bridge void*)self));
    
    _volumeMeterTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(monitorVolume) userInfo:nil repeats:YES];
}
- (void)monitorVolume {
    NSDictionary* info = @{ @"decibelLevel":[NSNumber numberWithFloat:_lastDbLevel] };
    [BTAppDelegate notify:@"BTAudio.decibelMeter" info:info];
}
- (void)stopRecordingToFileAndScheduleStop {
    _recording = NO;
}
static OSStatus recordFromUnitToFile (void *inRefCon, AudioUnitRenderActionFlags* ioActionFlags, const AudioTimeStamp* inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    BOOL isPostRender = (*ioActionFlags & kAudioUnitRenderAction_PostRender);
    if (!isPostRender) { return noErr; }

    BTAudioGraph* THIS = (__bridge BTAudioGraph *)inRefCon;
    if (THIS->_recording) {
        check(@"Record data to file", ExtAudioFileWriteAsync(THIS->_recordToAudioExtFileRef, inNumberFrames, ioData));
    } else if (THIS->_recordToAudioExtFileRef) {
        [THIS cleanupRecording];
    }
    
    THIS->_lastDbLevel = getDbLevel(inNumberFrames, ioData->mBuffers[0].mData);
    
    return noErr;
}
- (void)cleanupRecording {
    check(@"Dispose of recording file", ExtAudioFileDispose(_recordToAudioExtFileRef));
    _recordToAudioExtFileRef = nil;
    [self stop];
}


- (FileInfo*) readFile:(NSString*)filepath toNode:(AUNode)node bus:(AudioUnitElement)bus {
    AUNode filePlayerNode = [self addNodeNamed:@"readFile" type:kAudioUnitType_Generator subType:kAudioUnitSubType_AudioFilePlayer];
    [self connectNode:filePlayerNode bus:0 toNode:node bus:bus]; // Node must be connected before priming the file unit player
    AudioUnit fileAU = [self getUnit:filePlayerNode];
    
    AudioFileID inputFile;
    check(@"Open audio file", AudioFileOpenURL(getFileUrl(filepath), kAudioFileReadPermission, 0, &inputFile));
    
    AudioStreamBasicDescription fileFormat;
    UInt32 inputFormatSize = sizeof(fileFormat);
    check(@"Get audio file format", AudioFileGetProperty(inputFile, kAudioFilePropertyDataFormat, &inputFormatSize, &fileFormat));
    
    check(@"Set file player file id", AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &(inputFile), sizeof((inputFile))));
    
    UInt64 nPackets;
    UInt32 nPacketsSize = sizeof(nPackets);
    check(@"Get file audio packet count", AudioFileGetProperty(inputFile, kAudioFilePropertyAudioDataPacketCount, &nPacketsSize, &nPackets));
    
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
    rgn.mFramesToPlay = nPackets * fileFormat.mFramesPerPacket;
    
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

    return [[FileInfo alloc] initWithFileFormat:fileFormat numPackets:nPackets fileNode:filePlayerNode];
}


/* Audio graph wrapper Utilities
 *******************************/

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


#define DBOFFSET -148.0
// DBOFFSET is An offset that will be used to normalize the decibels to a maximum of zero.
// This is an estimate, you can do your own or construct an experiment to find the right value
#define LOWPASSFILTERTIMESLICE .001
// LOWPASSFILTERTIMESLICE is part of the low pass filter and should be a small positive value
Float32 getDbLevel(UInt32 inNumberFrames, UInt32* samples) {
    Float32 decibels = DBOFFSET; // When we have no signal we'll leave this on the lowest setting
    Float32 currentFilteredValueOfSampleAmplitude, previousFilteredValueOfSampleAmplitude; // We'll need these in the low-pass filter
    Float32 peakValue = DBOFFSET; // We'll end up storing the peak value here
    
    for (int i=0; i < inNumberFrames; i++) {
        
        Float32 absoluteValueOfSampleAmplitude = abs(samples[i]); //Step 2: for each sample, get its amplitude's absolute value.
        
        // Step 3: for each sample's absolute value, run it through a simple low-pass filter
        // Begin low-pass filter
        currentFilteredValueOfSampleAmplitude = LOWPASSFILTERTIMESLICE * absoluteValueOfSampleAmplitude + (1.0 - LOWPASSFILTERTIMESLICE) * previousFilteredValueOfSampleAmplitude;
        previousFilteredValueOfSampleAmplitude = currentFilteredValueOfSampleAmplitude;
        Float32 amplitudeToConvertToDB = currentFilteredValueOfSampleAmplitude;
        // End low-pass filter
        
        Float32 sampleDB = 20.0*log10(amplitudeToConvertToDB) + DBOFFSET;
        // Step 4: for each sample's filtered absolute value, convert it into decibels
        // Step 5: for each sample's filtered absolute value in decibels, add an offset value that normalizes the clipping point of the device to zero.
        
        if((sampleDB == sampleDB) && (sampleDB != -DBL_MAX)) { // if it's a rational number and isn't infinite
            
            if(sampleDB > peakValue) peakValue = sampleDB; // Step 6: keep the highest value you find.
            decibels = peakValue; // final value
        }
    }
    return decibels;
}
@end

