//
//  BTModule.h
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Flutterby. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTAppDelegate.h"
#import "NSArray+HHFunctional.h"
#import "NSArray+NSString+HHMakeStructs.h"
#import "NSString+HHUriEncoding.h"

@interface BTModule : NSObject
+ (void) setup:(BTAppDelegate*)app;
- (void) setup:(BTAppDelegate*)app;
+ (void) module:(NSString*)module getMedia:(NSString*)mediaId callback:(BTCallback)callback;
- (void) getMedia:(NSString*)mediaId callback:(BTCallback)callback;
- (void) notify:(NSString*)event;
- (void) notify:(NSString*)event info:(NSDictionary*)info;

- (void)async:(void (^)())asyncBlock;
- (void)asyncBackground:(void (^)())asyncBackgroundPriorityBlock;
- (void)asyncHighPriority:(void (^)())asyncHighPriorityBlock;
- (void)asyncLowPriority:(void (^)())asyncLowPriorityBlock;
- (void)asyncMainQueue:(void (^)())asyncMainBlock;

@end
