//
//  BTTextInput.h
//  dogo
//
//  Created by Marcus Westin on 10/7/12.
//  Copyright (c) 2012 Flutterby Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTModule.h"

@interface BTTextInput : BTModule <UITextViewDelegate>
@property (strong,nonatomic,readonly) UITextView* textInput;

+ (BTTextInput*) instance;
@end
