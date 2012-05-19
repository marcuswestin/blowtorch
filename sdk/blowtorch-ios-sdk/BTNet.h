//
//  BTNet.h
//  dogo
//
//  Created by Marcus Westin on 5/19/12.
//  Copyright (c) 2012 Meebo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BTTypes.h"

@interface BTNet : NSObject

@property (nonatomic,strong) MKNetworkEngine* engine;

- (void)cache:(NSString*)url override:(BOOL)override responseCallback:(ResponseCallback)responseCallback;

+ (NSString *)urlEncodeValue:(NSString *)str;

+ (NSString*)pathForUrl:(NSString*)url;

@end
