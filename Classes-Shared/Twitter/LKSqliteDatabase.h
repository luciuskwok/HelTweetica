//
//  LKSqliteDatabase.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <sqlite3.h>
#import "LKSqliteStatement.h"


@interface LKSqliteDatabase : NSObject {
	sqlite3 *database;
}

- (id)initWithFile:(NSString*)file;

- (NSString *)queryWithCommand:(NSString*)command table:(NSString*)table keys:(NSArray *)keys;
- (LKSqliteStatement*)statementWithQuery:(NSString*)aQuery;

- (int)execute:(NSString*)aQuery;
- (void)beginTransaction;
- (void)endTransaction;

+ (void)runTests;

@end
