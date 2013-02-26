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

@interface BTAudioGraph : NSObject
@property (nonatomic,assign,readonly) AUNode ioNode;
@property (nonatomic,assign,readonly) AudioUnit ioUnit;
- (void) readFile:(NSString*)filepath toNode:(AUNode)node bus:(AudioUnitElement)bus;
- (id) initWithSpeaker;
- (id) initWithSpeakerAndMicrophoneInput;
- (BOOL) start;
- (BOOL) stop;
- (AUNode) addNodeOfType:(OSType)type subType:(OSType)subType;
- (AudioUnit) getUnit:(AUNode)node;
- (BOOL) connectNode:(AUNode)nodeA bus:(UInt32)busA toNode:(AUNode)nodeB bus:(UInt32)busB;
- (void)recordFromUnit:(AudioUnit)unit bus:(AudioUnitElement)bus toFile:(NSString *)filepath;
BOOL check(NSString* str, OSStatus status);
BOOL setOutputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd);
BOOL setInputStreamFormat(AudioUnit unit, AudioUnitElement bus, AudioStreamBasicDescription asbd);
AudioStreamBasicDescription getInputStreamFormat(AudioUnit unit, AudioUnitElement bus);
AVAudioSession* createAudioSession(NSString* category);
@end
