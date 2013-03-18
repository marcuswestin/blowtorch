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
    
    [app handleCommand:@"BTSql.openDatabase" handler:^(id data, BTCallback responseCallback) {
        [self openDatabase:data callback:responseCallback];
    }];
    [app handleCommand:@"BTSql.query" handler:^(id data, BTCallback responseCallback) {
        [self executeQuery:data[@"sql"] arguments:data[@"arguments"] callback:responseCallback];
    }];
    [app handleCommand:@"BTSql.update" handler:^(id data, BTCallback responseCallback) {
        [self executeUpdate:data[@"sql"] arguments:data[@"arguments"] ignoreDuplicates:[data[@"ignoreDuplicates"] boolValue] callback:responseCallback];
    }];
    [app handleCommand:@"BTSql.insertMultiple" handler:^(id data, BTCallback callback) {
        [self insertMultiple:data[@"sql"] argumentsList:data[@"argumentsList"] ignoreDuplicates:[data[@"ignoreDuplicates"] boolValue] callback:callback];
    }];
//    [app handleCommand:@"BTSql.transact" handler:^(id data, BTCallback responseCallback) {
//        [self transact:data callback:responseCallback];
//    }];
}

- (void) openDatabase:(NSDictionary*)data callback:(BTCallback)callback {
    queue = [FMDatabaseQueue databaseQueueWithPath:[BTFiles documentPath:data[@"name"]]];
    callback(nil,nil);
}

- (void)executeQuery:(NSString *)sql arguments:(NSArray *)arguments callback:(BTCallback)callback {
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

- (void)executeUpdate:(NSString *)sql arguments:(NSArray *)arguments ignoreDuplicates:(BOOL)ignoreDuplicates callback:(BTCallback)callback {
    [self async:^{
        [queue inDatabase:^(FMDatabase *db) {
            BOOL success = [db executeUpdate:sql withArgumentsInArray:arguments];
            if (!success && ignoreDuplicates && db.lastErrorCode == SQLITE_CONSTRAINT) { success = YES; }
            callback(success ? nil : db.lastError, nil);
        }];
    }];
}

- (void)insertMultiple:(NSString*)sql argumentsList:(NSArray*)argumentsList ignoreDuplicates:(BOOL)ignoreDuplicates callback:(BTCallback)callback {
    [self async:^{
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSArray* arguments in argumentsList) {
                BOOL success = [db executeUpdate:sql withArgumentsInArray:arguments];
                if (!success) {
                    if (ignoreDuplicates && db.lastErrorCode == SQLITE_CONSTRAINT) { continue; }
                    return callback(db.lastError, nil);
                }
            }
            callback(nil,nil);
        }];
    }];
}

//- (void) transact:(NSDictionary*)data callback:(BTCallback)callback {
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
