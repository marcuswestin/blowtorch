//
//  BTState.h
//  dogo
//
//  Created by Marcus Westin on 5/1/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BTState : NSObject

- (void) set:(NSString*)key value:(id)value;
- (id) get:(NSString*)key;
- (NSDictionary*) load;
- (void) reset;

- (NSString *)getFilePath;

@end
