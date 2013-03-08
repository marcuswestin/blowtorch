//
//  BTAudioGraph.h
//  dogo
//
//  Created by Marcus Westin on 2/25/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "BTFiles.h"

const AudioUnitElement RIOInputFromMic;
const AudioUnitElement RIOInputFromApp;
const AudioUnitElement RIOOutputToSpeaker;
const AudioUnitElement RIOOutputToApp;

@interface FileInfo : NSObject
@property (readonly) AudioStreamBasicDescription fileFormat;
@property (readonly) UInt64 numPackets;
@property (readonly) AUNode fileNode;
@end

@interface BTAudioGraph : NSObject
@property (nonatomic,assign,readonly) AUNode ioNode;
@property (nonatomic,assign,readonly) AudioUnit ioUnit;

- (id) initWithSpeaker;
- (id) initWithSpeakerAndMicrophoneInput;
- (id) initWithSpearkAndVoiceInput;
- (id) initWithOfflineIO;
- (id) initWithNoIO;

- (BOOL) start;
- (BOOL) stop;

- (AUNode) addNodeNamed:(NSString*)nodeName type:(OSType)type subType:(OSType)subType;
- (AUNode) getNodeNamed:(NSString*)nodeName;
- (AudioUnit) getUnit:(AUNode)node;
- (AudioUnit) getUnitNamed:(NSString*)nodeName;

- (BOOL) connectNode:(AUNode)nodeA bus:(UInt32)busA toNode:(AUNode)nodeB bus:(UInt32)busB;

- (FileInfo*) readFile:(NSString*)filepath toNode:(AUNode)node bus:(AudioUnitElement)bus;
- (void) recordFromNode:(AUNode)node bus:(AudioUnitElement)bus toFile:(NSString *)filepath;
- (void) stopRecordingToFileAndScheduleStop;
- (void) cleanupRecording;

BOOL setOutputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd);
BOOL setInputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd);
AudioStreamBasicDescription getInputStreamFormat(AudioUnit unit, AudioUnitElement bus);
AudioStreamBasicDescription getOutputStreamFormat(AudioUnit unit, AudioUnitElement bus);
AVAudioSession* createAudioSession(NSString* category);
BOOL check(NSString* str, OSStatus status);

@end
