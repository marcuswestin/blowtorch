//
//  BTModule.h
//  dogo
//
//  Created by Marcus Westin on 10/13/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTAppDelegate.h"

@interface BTModule : NSObject

+ (void) setup:(BTAppDelegate*)app;
- (void) setup:(BTAppDelegate*)app;

@end
