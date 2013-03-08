//
//  BTSql.h
//  dogo
//
//  Created by Marcus Westin on 3/5/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTModule.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

@interface BTSql : BTModule

+ (FMDatabaseQueue*) getQueue;

@end
