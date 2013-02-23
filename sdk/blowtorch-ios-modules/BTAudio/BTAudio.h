//
//  BTAudio.h
//  dogo
//
//  Created by Marcus Westin on 1/10/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "BTModule.h"

@interface BTAudio : BTModule <AVAudioRecorderDelegate, AVAudioPlayerDelegate>

//+ (NSURL*)getFileLocation;

@end
