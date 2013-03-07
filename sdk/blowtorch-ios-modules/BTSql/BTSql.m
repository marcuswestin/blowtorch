//
//  BTSql.m
//  dogo
//
//  Created by Marcus Westin on 3/5/13.
//  Copyright (c) 2013 Flutterby. All rights reserved.
//

#import "BTSql.h"
#import "BTFiles.h"

@implementation BTSql {
    FMDatabaseQueue* queue;
}

static BTSql* instance;

+ (FMDatabaseQueue *)getQueue { return instance.queue; }
- (FMDatabaseQueue*) queue { return queue; }

- (void)setup:(BTAppDelegate *)app {
    if (instance) { return; }
    instance = self;
    
    [app registerHandler:@"BTSql.openDatabase" handler:^(id data, BTResponseCallback responseCallback) {
        [self openDatabase:data callback:responseCallback];
    }];
    [app registerHandler:@"BTSql.query" handler:^(id data, BTResponseCallback responseCallback) {
        [self executeQuery:data[@"sql"] arguments:data[@"arguments"] callback:responseCallback];
    }];
    [app registerHandler:@"BTSql.update" handler:^(id data, BTResponseCallback responseCallback) {
        [self executeUpdate:data[@"sql"] arguments:data[@"arguments"] callback:responseCallback];
    }];
    [app registerHandler:@"BTSql.insertMultiple" handler:^(id data, BTResponseCallback callback) {
        [self insertMultiple:data[@"sql"] ignoreDuplicates:[data[@"ignoreDuplicates"] boolValue] argumentsList:data[@"argumentsList"] callback:callback];
    }];
//    [app registerHandler:@"BTSql.transact" handler:^(id data, BTResponseCallback responseCallback) {
//        [self transact:data callback:responseCallback];
//    }];
}

- (void) openDatabase:(NSDictionary*)data callback:(BTResponseCallback)callback {
    queue = [FMDatabaseQueue databaseQueueWithPath:[BTFiles documentPath:data[@"name"]]];
    callback(nil,nil);
}

- (void)executeQuery:(NSString *)sql arguments:(NSArray *)arguments callback:(BTResponseCallback)callback {
    [self async:^{
        [queue inDatabase:^(FMDatabase *db) {
            FMResultSet* resultSet = [db executeQuery:sql withArgumentsInArray:arguments];
            NSMutableArray* rows = [NSMutableArray array];
            while ([resultSet next]) {
                [rows addObject:[resultSet resultDictionary]];
            }
            callback(nil, @{ @"rows":rows });
        }];
    }];
}

- (void)executeUpdate:(NSString *)sql arguments:(NSArray *)arguments callback:(BTResponseCallback)callback {
    [self async:^{
        [queue inDatabase:^(FMDatabase *db) {
            BOOL success = [db executeUpdate:sql withArgumentsInArray:arguments];
            callback(success ? nil : db.lastError, nil);
        }];
    }];
}

- (void)insertMultiple:(NSString*)sql ignoreDuplicates:(BOOL)ignoreDuplicates argumentsList:(NSArray*)argumentsList callback:(BTResponseCallback)callback {
    [self async:^{
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSArray* arguments in argumentsList) {
                BOOL success = [db executeUpdate:sql withArgumentsInArray:arguments];
                if (!success) {
                    if (ignoreDuplicates && db.lastErrorCode == SQLITE_CONSTRAINT) { continue; }
                    NSLog(@"QWEQWE %@ %@", sql, arguments);
                    return callback(db.lastError, nil);
                }
            }
            callback(nil,nil);
        }];
    }];
}

- (void)async:(void (^)())asyncBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), asyncBlock);
}

//- (void) transact:(NSDictionary*)data callback:(BTResponseCallback)callback {
//    [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
//        for (NSDictionary* update in data[@"updates"]) {
//            BOOL success = [db executeUpdate:update[@"sql"] withArgumentsInArray:update[@"arguments"]];
//            if (!success) {
//                *rollback = YES;
//                callback(db.lastError, nil);
//                return;
//            }
//        }
//        callback(nil,nil);
//    }];
//}

@end
