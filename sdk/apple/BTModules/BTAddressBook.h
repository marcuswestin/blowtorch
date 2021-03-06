//
//  BTAddressBook.h
//  dogo
//
//  Created by Marcus Westin on 2/21/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTModule.h"

@interface BTAddressBook : BTModule

+ (void)allEntries:(BTCallback)callback;
+ (NSData*)getRecordImage:(NSString*)recordId;

@end
