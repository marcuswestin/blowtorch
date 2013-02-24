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

const AudioUnitElement RIOInputFromMic = 1;
const AudioUnitElement RIOInputFromApp = 0;
const AudioUnitElement RIOOutputToSpeaker = 0;
const AudioUnitElement RIOOutputToApp = 1;

BOOL setOutputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd) {
    OSStatus status = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus, &asbd, sizeof(asbd));
    return checkError(status, @"Set output stream format");
}
BOOL setInputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd) {
    OSStatus status = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus, &asbd, sizeof(asbd));
    return checkError(status, @"Set stream format");
}

AudioStreamBasicDescription getInputStreamFormat(AudioUnit unit, AudioUnitElement bus) {
    return getStreamFormat(unit, kAudioUnitScope_Input, bus);
}
AudioStreamBasicDescription getOutputStreamFormat(AudioUnit unit, AudioUnitElement bus) {
    return getStreamFormat(unit, kAudioUnitScope_Output, bus);
}
AudioStreamBasicDescription getStreamFormat(AudioUnit unit, AudioUnitScope scope, AudioUnitElement bus) {
    AudioStreamBasicDescription streamFormat;
    memset(&streamFormat, 0, sizeof(streamFormat));
    UInt32 size = sizeof(streamFormat);
    checkError(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, scope, bus, &streamFormat, &size), @"Get stream format");
    return streamFormat;
}

BOOL setGlobalPropertyInt(AudioUnit unit ,AudioUnitPropertyID propertyId, UInt32 data) {
    return setPropertyInt(unit, propertyId, kAudioUnitScope_Global, 0, data);
}
// The input and output scopes move audio streams through the audio unit: audio enters at the input scope and leaves at the output scope.
BOOL setInputPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitElement element, UInt32 data) {
    return setPropertyInt(unit, propertyId, kAudioUnitScope_Input, element, data);
}
BOOL setOutputPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitElement element, UInt32 data) {
    return setPropertyInt(unit, propertyId, kAudioUnitScope_Output, element, data);
}
// Properties: http://developer.apple.com/library/ios/#documentation/AudioUnit/Reference/AudioUnitPropertiesReference/Reference/reference.html
// Scopes: kAudioUnitScope_* (Global, Input, Output, Group, Part, Note)
// Input scope is audio coming into the AU, output is going out of the unit, and global is for properties that affect the whole unit
BOOL setPropertyInt(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitScope scope, AudioUnitElement element, UInt32 data) {
    OSStatus status = AudioUnitSetProperty(unit, propertyId, scope, element, &data, sizeof(data));
    return checkError(status, @"Setting property");
}
AudioUnitParameterValue getParameter(AudioUnit unit, AudioUnitPropertyID propertyId, AudioUnitScope scope, AudioUnitElement element) {
    AudioUnitParameterValue value;
    OSStatus status = AudioUnitGetParameter(unit, propertyId, scope, element, &value);
    if (!checkError(status, @"Get parameter")) { return 0; }
    return value;
}

- (void) playFromFile {
    {
        //create a new AUGraph
        CheckError(NewAUGraph(&_graph), "NewAUGraph failed");
        // opening the graph opens all contained audio units but does not allocate any resources yet
        CheckError(AUGraphOpen(_graph), "AUGraphOpen failed");
        // now initialize the graph (causes resources to be allocated)
        CheckError(AUGraphInitialize(_graph), "AUGraphInitialize failed");
    }
    
    AUNode outputNode;
    {
        AudioComponentDescription outputAudioDesc = {0};
        outputAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        outputAudioDesc.componentType = kAudioUnitType_Output;
        outputAudioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
        // adds a node with above description to the graph
        CheckError(AUGraphAddNode(_graph, &outputAudioDesc, &outputNode), "AUGraphAddNode[kAudioUnitSubType_DefaultOutput] failed");
    }
    
    AUNode filePlayerNode;
    {
        AudioComponentDescription fileplayerAudioDesc = {0};
        fileplayerAudioDesc.componentType = kAudioUnitType_Generator;
        fileplayerAudioDesc.componentSubType = kAudioUnitSubType_AudioFilePlayer;
        fileplayerAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        // adds a node with above description to the graph
        CheckError(AUGraphAddNode(_graph, &fileplayerAudioDesc, &filePlayerNode), "AUGraphAddNode[kAudioUnitSubType_AudioFilePlayer] failed");
    }
    
    //Connect the nodes
    {
        CheckError(AUGraphConnectNodeInput(_graph, filePlayerNode, 0, outputNode, 0), "AUGraphConnectNodeInput");
    }
    
    
    
    // configure the file player
    // tell the file player unit to load the file we want to play
    {
        //?????
        AudioStreamBasicDescription inputFormat; // input file's data stream description
        AudioFileID inputFile; // reference to your input file
        
        // open the input audio file and store the AU ref in _player
        CheckError(AudioFileOpenURL(getFileUrl(@"audio.m4a"), kAudioFileReadPermission, 0, &inputFile), "AudioFileOpenURL failed");
        
        //create an empty MyAUGraphPlayer struct
        AudioUnit fileAU;
        
        // get the reference to the AudioUnit object for the file player graph node
        CheckError(AUGraphNodeInfo(_graph, filePlayerNode, NULL, &fileAU), "AUGraphNodeInfo failed");
        
        // get and store the audio data format from the file
        UInt32 propSize = sizeof(inputFormat);
        CheckError(AudioFileGetProperty(inputFile, kAudioFilePropertyDataFormat, &propSize, &inputFormat), "couldn't get file's data format");
        
        CheckError(AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &(inputFile), sizeof((inputFile))), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs] failed");
        
        UInt64 nPackets;
        UInt32 propsize = sizeof(nPackets);
        CheckError(AudioFileGetProperty(inputFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets), "AudioFileGetProperty[kAudioFilePropertyAudioDataPacketCount] failed");
        
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
        
        CheckError(AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0,&rgn, sizeof(rgn)), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion] failed");
        
        // prime the file player AU with default values
        UInt32 defaultVal = 0;
        CheckError(AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal)), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime] failed");
        
        // tell the file player AU when to start playing (-1 sample time means next render cycle)
        AudioTimeStamp startTime;
        memset (&startTime, 0, sizeof(startTime));
        startTime.mFlags = kAudioTimeStampSampleTimeValid;
        startTime.mSampleTime = -1;
        CheckError(AudioUnitSetProperty(fileAU, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)), "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");
        
        // file duration
        //double duration = (nPackets * _player.inputFormat.mFramesPerPacket) / _player.inputFormat.mSampleRate;
    }
    
    checkError(AUGraphInitialize(_graph), @"Initialize graph");
    [self startGraph];
}

static BOOL RECORD = NO;

- (void) recordToFile {
    [self createSessionForPlayAndRecord];
    [self createAndOpenGraph];
    if (!_session.inputAvailable) { NSLog(@"WARNING Requested input is not available");}

    AUNode rioNode = [self setVoiceIoNode];
    AudioUnit rioUnit = [self getUnit:rioNode];

    [self connectNode:rioNode bus:RIOOutputToApp toNode:rioNode bus:RIOInputFromApp];
    setInputPropertyInt(rioUnit, kAudioOutputUnitProperty_EnableIO, RIOInputFromMic, 1);
    
    // Describe format - - - - - - - - - -
    AudioStreamBasicDescription audioFormat;
    memset(&audioFormat, 0, sizeof(audioFormat));
    audioFormat.mSampleRate   = 44100.00;
    audioFormat.mFormatID     = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags    = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel   = 16;
    audioFormat.mBytesPerPacket   = 2;
    audioFormat.mBytesPerFrame    = 2;
    
    setOutputStreamFormat(rioUnit, RIOOutputToApp, audioFormat);
    setInputStreamFormat(rioUnit, RIOInputFromApp, audioFormat);
    
    {
        
        OSStatus result;
        
        AudioStreamBasicDescription fileFormat = [self getFileFormat];
        result = ExtAudioFileCreateWithURL(getFileUrl(@"audio.m4a"), kAudioFileM4AType, &fileFormat, NULL, kAudioFileFlags_EraseFile, &extAudioFileRef);
        if(result) printf("ExtAudioFileCreateWithURL %ld \n", result);
        
        // specify codec
        UInt32 codec = kAppleHardwareAudioCodecManufacturer;
        result = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_CodecManufacturer, sizeof(codec), &codec);
        if(result) printf("ExtAudioFileSetProperty 1 %ld \n", result);
        
        AudioStreamBasicDescription clientFormat;
        UInt32 clientFormatSize = sizeof(clientFormat);
        memset(&clientFormat, 0, clientFormatSize);
        result = AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &clientFormat, &clientFormatSize);
        if(result) printf("AudioUnitGetProperty %ld \n", result);
        
        result = ExtAudioFileSetProperty(extAudioFileRef,kExtAudioFileProperty_ClientDataFormat,sizeof(clientFormat),&clientFormat);
        if(result) printf("ExtAudioFileSetProperty 2 %ld \n", result);
        
        result =  ExtAudioFileWriteAsync(extAudioFileRef, 0, NULL);
        if (result) {[self printErrorMessage: @"ExtAudioFileWriteAsync error" withStatus: result];}
        
        result = AudioUnitAddRenderNotify(rioUnit, renderCallback, (__bridge void*)self);
        if (result) {[self printErrorMessage: @"AudioUnitAddRenderNotify" withStatus: result];}
    }
    
    checkError(AUGraphInitialize(_graph), @"Initialize graph");
    [self startGraph]; // Finally, recording!
}

CFURLRef getFileUrl(NSString* filename) {
    return CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge   CFStringRef)[BTFiles documentPath:filename], kCFURLPOSIXPathStyle, false);
}

- (AudioStreamBasicDescription) getFileFormat {
    AudioStreamBasicDescription destinationFormat;
    memset(&destinationFormat, 0, sizeof(destinationFormat));
    destinationFormat.mChannelsPerFrame = 2;
    destinationFormat.mFormatID = kAudioFormatMPEG4AAC;
    UInt32 size = sizeof(destinationFormat);
    OSStatus result = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destinationFormat);
    if(result) printf("AudioFormatGetProperty %ld \n", result);
    return destinationFormat;
}

static int count = 0;

static OSStatus renderCallback (void *                       inRefCon,
                                AudioUnitRenderActionFlags * ioActionFlags,
                                const AudioTimeStamp *       inTimeStamp,
                                UInt32                       inBusNumber,
                                UInt32                       inNumberFrames,
                                AudioBufferList *            ioData)
{
    
    OSStatus result;
    if (*ioActionFlags != kAudioUnitRenderAction_PostRender) { return noErr; }
    
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


- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;

    if (RECORD) { [self recordToFile]; }
    else { [self playFromFile]; }
    
    // First, record audio to a file while visualizing audio
//    [self createSessionForPlayAndRecord];
//    [self createAndOpenGraph];
//    
//    if (!_session.inputAvailable) { NSLog(@"WARNING Requested input is not available");}
    
//    // Create pitch node
//    float pitchMax = 2400; // min = -2400
//    AUNode pitchNode = [self addNodeOfType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_NewTimePitch];
//    AudioUnit pitchUnit = [self getUnit:pitchNode];
//    checkError(AudioUnitSetParameter(pitchUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitchMax - 500, 0), @"Set pitch");
    
    // Create IO node
//    AUNode rioNode = [self setVoiceIoNode];
//    AudioUnit rioUnit = [self getUnit:rioNode];
//    [self setInput:rioUnit property:kAudioOutputUnitProperty_EnableIO element:RIOInputFromMic data:1];
    
    // Connect IO Node:app output -> Pitch Node:0 -> IO Node:app input
//    AudioStreamBasicDescription streamFormat = getStreamFormat(pitchUnit, kAudioUnitScope_Input, 0);
    
    //    setOutputStreamFormat(rioUnit, RIOOutputToApp, streamFormat);
    //    setInputStreamFormat(rioUnit, RIOInputFromApp, streamFormat);
    //    [self connectNode:rioNode bus:RIOOutputToApp toNode:pitchNode bus:0];
    //    [self connectNode:pitchNode bus:0 toNode:rioNode bus:RIOInputFromApp];



    //    AudioUnitAddRenderNotify(pitchUnit, MyAURenderCallback, NULL);
//    AudioUnitSetProperty(ioUnit,
//                         kAudioUnitProperty_SetRenderCallback,
//                         kAudioUnitScope_Output,
//                         RIOOutputToSpeaker,
//                         &callbackStruct,
//                         sizeof(callbackStruct));
    
    
//    checkError(AUGraphInitialize(_graph), @"Initialize graph");
//    [self startGraph]; // Finally, recording!
    
    // Second, playback audio file through effect graph
    
    // Third, apply effect into new file, and send that file to server
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







// 1) Create & open graph
- (BOOL) createAndOpenGraph {
    if (!checkError(NewAUGraph(&_graph), @"Creating graph")) { return NO; }
    if (!checkError(AUGraphOpen(_graph), @"Open graph")) { return NO; }
    return YES;
}
// 2) Add nodes to graph
//                          -------------------------
//                          | i                   o |
// -- BUS 1 -- from mic --> | n    REMOTE I/O     u | -- BUS 1 -- to app -->
//                          | p      AUDIO        t |
// -- BUS 0 -- from app --> | u       UNIT        p | -- BUS 0 -- to speaker -->
//                          | t                   u |
//                          |                     t |
//                          -------------------------




- (AUNode) setMicrophoneIoNode {
    return [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO];
}
- (AUNode) setVoiceIoNode {
    return [self addNodeOfType:kAudioUnitType_Output subType:kAudioUnitSubType_VoiceProcessingIO];
}
- (AUNode) addNodeOfType:(OSType)type subType:(OSType)subType {
    return [self addNode:[self _description:type subType:subType]];
}
- (AUNode) addNode:(AudioComponentDescription)componentDescription {
    AUNode node;
    OSStatus status = AUGraphAddNode(_graph, &componentDescription, &node);
    if (!checkError(status, @"Adding node")) { return 0; }
    return node;
}





// 4) Configure graph node units
- (AudioUnit) getUnit:(AUNode)node {
    AudioUnit unit;
    OSStatus status = AUGraphNodeInfo(_graph, node, NULL, &unit);
    if (!checkError(status, @"Getting unit")) { return NULL; }
    return unit;
}
- (BOOL) setGlobalProperty:(AudioUnit)unit property:(AudioUnitPropertyID)propertyId data:(UInt32)data {
    return [self setProperty:unit property:propertyId scope:kAudioUnitScope_Global element:0 data:data];
}
// The input and output scopes move audio streams through the audio unit: audio enters at the input scope and leaves at the output scope.
- (BOOL) setInput:(AudioUnit)unit property:(AudioUnitPropertyID)propertyId element:(AudioUnitElement)element data:(UInt32)data {
    return [self setProperty:unit property:propertyId scope:kAudioUnitScope_Input element:element data:data];
}
- (BOOL) setOutput:(AudioUnit)unit property:(AudioUnitPropertyID)propertyId element:(AudioUnitElement)element data:(UInt32)data {
    return [self setProperty:unit property:propertyId scope:kAudioUnitScope_Output element:element data:data];
}
// Properties: http://developer.apple.com/library/ios/#documentation/AudioUnit/Reference/AudioUnitPropertiesReference/Reference/reference.html
// Scopes: kAudioUnitScope_* (Global, Input, Output, Group, Part, Note)
// Input scope is audio coming into the AU, output is going out of the unit, and global is for properties that affect the whole unit
- (BOOL) setProperty:(AudioUnit)unit property:(AudioUnitPropertyID)propertyId scope:(AudioUnitScope)scope element:(AudioUnitElement)element data:(UInt32)data {
    OSStatus status = AudioUnitSetProperty(unit, propertyId, scope, element, &data, sizeof(data));
    return checkError(status, @"Setting property");
}
- (AudioUnitParameterValue) getParameter:(AudioUnit)unit property:(AudioUnitPropertyID)propertyId scope:(AudioUnitScope)scope element:(AudioUnitElement)element {
    AudioUnitParameterValue value;
    OSStatus status = AudioUnitGetParameter(unit, propertyId, scope, element, &value);
    if (!checkError(status, @"Get parameter")) { return 0; }
    return value;
}





// 5) Connect nodes in the graph
- (BOOL) connectNode:(AUNode)nodeA bus:(UInt32)busA toNode:(AUNode)nodeB bus:(UInt32)busB {
    OSStatus status = AUGraphConnectNodeInput(_graph, nodeA, busA, nodeB, busB);
    return checkError(status, @"Connecting nodes");
}






// 6) Start and stop audio flow
- (BOOL) startGraph {
    return checkError(AUGraphStart(_graph), @"Start graph");
}
- (BOOL) stopGraph {
    Boolean isRunning = false;
    if (!checkError(AUGraphIsRunning(_graph, &isRunning), @"Check graph running")) { return NO; }
    return isRunning ? checkError(AUGraphStop(_graph), @"Stop graph") : YES;
}







/* Utilities
 ***********/
- (AudioComponentDescription) _description:(OSType)type subType:(OSType)subType {
    return [self _description:type subType:subType manufacturer:kAudioUnitManufacturer_Apple flags:0 mask:0];
}
- (AudioComponentDescription) _description:(OSType)type subType:(OSType)subType manufacturer:(OSType)manufacturer flags:(UInt32)flags mask:(UInt32)mask {
    AudioComponentDescription iOUnitDescription;
    iOUnitDescription.componentType = type;
    iOUnitDescription.componentSubType = subType;
    iOUnitDescription.componentManufacturer = manufacturer;
    iOUnitDescription.componentFlags = flags;
    iOUnitDescription.componentFlagsMask = mask;
    return iOUnitDescription;
}
- (void) printErrorMessage: (NSString*)errorString withStatus:(OSStatus)status {
    error(errorString, status);
}
BOOL checkError(OSStatus status, NSString* errorString) {
    if (status == noErr) { return YES; }
    error(errorString, status);
    return NO;
}
BOOL CheckError(OSStatus status, char* errorString) {
    if (status == noErr) { return YES; }
    char str[20];
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) { // is it a 4-char-code?
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else { // no, format as an integer
		sprintf(str, "%d", (int)status);
    }
    return NO;
//    NSLog(@"*** %@ error: %s\n", errorString, str);
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
@end






