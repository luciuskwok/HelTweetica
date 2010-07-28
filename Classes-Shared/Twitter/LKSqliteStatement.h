//
//  LKSquliteStatement.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <sqlite3.h>


@interface LKSqliteStatement : NSObject {
	sqlite3_stmt *statement;
}

- (id)initWithStatement:(sqlite3_stmt *)aStatement;

- (void)bindValue:(id)value atIndex:(int)index;
- (void)bindNullAtIndex:(int)index;
- (void)bindString:(NSString*)string atIndex:(int)index;
- (void)bindNumber:(NSNumber*)number atIndex:(int)index;
- (void)bindInteger:(SInt64)n atIndex:(int)index;
- (void)bindDate:(NSDate*)date atIndex:(int)index;

- (int)step;
- (id)objectForColumnIndex:(int)column;
- (NSDictionary *)rowData;
- (void)reset;

@end
