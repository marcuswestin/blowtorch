//
//  NSString+BTUtils.h
//  Dogo
//
//  Created by Marcus Westin on 6/13/13.
//  Copyright (c) 2013 Flutterby Labs Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (BTUtils)

- (CGRect)makeRect;
- (CGSize)makeSize;
- (CGPoint)makePoint;

- (NSString*)encodeURIComponent;
- (NSString*)decodeURIComponent;
- (NSMutableDictionary*)parseQueryParams;

@end
