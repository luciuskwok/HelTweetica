//
//  LKSqliteDatabase.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKSqliteDatabase.h"


@implementation LKSqliteDatabase

- (id)initWithFile:(NSString*)file {
	self = [super init];
	if (self) {
		//int error = sqlite3_open_v2([file cStringUsingEncoding:NSUTF8StringEncoding], &database, SQLITE_OPEN_CREATE, nil);
		int error = sqlite3_open ([file cStringUsingEncoding:NSUTF8StringEncoding], &database);
		if (error != SQLITE_OK) {
			NSLog (@"Error result from sqlite3_open(): %d", error);
			sqlite3_close (database);
			self = nil;
		}
	}
	return self;
}

- (void)dealloc {
	// Close the sqlite connection.
	if (database != nil) {
		int error = sqlite3_close (database);
		if (error != SQLITE_OK) NSLog (@"Error result from sqlite3_close(): %d", error);
	}
	[super dealloc];
}

- (NSString *)queryWithCommand:(NSString*)command table:(NSString*)table keys:(NSArray *)keys {
	NSMutableString *queryKeys = [NSMutableString string];
	NSMutableString *valuePlaceholders = [NSMutableString string];
	BOOL firstItem = YES;
	for (NSString *key in keys) {
		// Insert separators between elements.
		if (firstItem == NO) {
			[queryKeys appendString:@", "];
			[valuePlaceholders appendString:@", "];
		}
		// Insert elements.
		[queryKeys appendString:key];
		[valuePlaceholders appendString:@"?"];
		
		firstItem = NO;
	}
	
	return [NSString stringWithFormat:@"%@ %@ (%@) VALUES (%@)", command, table, queryKeys, valuePlaceholders];
}

- (LKSqliteStatement*)statementWithQuery:(NSString*)aQuery {
	sqlite3_stmt *statement = nil;
	int error = sqlite3_prepare_v2 (database, [aQuery cStringUsingEncoding:NSUTF8StringEncoding], -1, &statement, nil);
	if (error != SQLITE_OK) {
		NSLog (@"Error result from sqlite3_prepare_v2(): %d", error);
		return nil;
	}
	
	return [[[LKSqliteStatement alloc] initWithStatement:statement] autorelease];
}

- (int)execute:(NSString*)aQuery {
	char *errorMessage = nil;
	int error = sqlite3_exec (database, [aQuery cStringUsingEncoding:NSUTF8StringEncoding], nil, nil, &errorMessage);
	if (error != SQLITE_OK) {
		NSLog (@"Error result from sqlite3_exec(): %d: %s", error, errorMessage);
		
	}
	if (errorMessage != nil)
		sqlite3_free(errorMessage);
	return error;
}

#pragma mark Testing

NSString *kTestName = @"screenName";
NSString *kFullName = @"Mr Name";
const SInt64 kTestUserID = 1234567890123;

- (void)testInsertRows {
	NSString *query = @"INSERT OR REPLACE INTO users (identifier, screenName, fullName) VALUES (?, ?, ?)";
	LKSqliteStatement *statement = [self statementWithQuery:query];
	
	// for loop
	// Bind variables
	[statement bindInteger:kTestUserID atIndex:1];
	[statement bindString:kTestName atIndex:2];
	[statement bindString:kFullName atIndex:3];
	
	// Execute statement.
	[statement step];
	
	// Reset statement for next run through loop.
	[statement reset];
	// end for loop
}

- (void)testSelectRowWith:(NSString *)screenName {
	NSString *query = @"SELECT * FROM users WHERE screenName LIKE ?";
	LKSqliteStatement *statement = [self statementWithQuery:query];
	[statement bindString:screenName atIndex:1];
	
	if ([statement step] == SQLITE_ROW) {
		// Get columns by index
		id value;
		int column;
		for (column = 0; column < 3; column++) {
			value = [statement objectForColumnIndex:column];
			NSLog (@"Column %d: %@", column, value);
		}
		
		// Get entire row as NSDictionary
		NSLog (@"Column dictionary: %@", [statement rowData]);
	} else {
		NSLog (@"Step did not return a row for %@.", screenName);
	} 
	
	[statement reset];
} 

+ (void)runTests {
	// Copy test file from template file if it doesn't exist.
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cachePath = [paths objectAtIndex:0];
	NSString *testFile = [cachePath stringByAppendingPathComponent:@"Test.db"];
		
	// Delete any existing test file
	if ([[NSFileManager defaultManager] fileExistsAtPath:testFile])
		[[NSFileManager defaultManager] removeItemAtPath:testFile error:nil];
	
	// Open or create test file.
	LKSqliteDatabase *db = [[LKSqliteDatabase alloc] initWithFile:testFile];
	
	// Use Autorelease pool to ensure statements are released before db.
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Add table.
	NSString *addTableQuery = @"create table users (identifier integer primary key, screenName text, fullName text)";
	[db execute:addTableQuery];
	
	// Add rows.
	[db testInsertRows];
	
	// Read rows.
	[db testSelectRowWith:kTestName];

	// Get a non-existant row
	[db testSelectRowWith:@"Bad Name"];

	// Close
	[pool release];
	[db release];
}

@end
