//
//  LKSquliteStatement.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKSqliteStatement.h"


@implementation LKSqliteStatement

- (id)initWithStatement:(sqlite3_stmt *)aStatement {
	self = [super init];
	if (self) {
		statement = aStatement;
	}
	return self;
}

#pragma mark Bind

- (void)bindValue:(id)value atIndex:(int)index {
	if (value == nil) {
		[self bindNullAtIndex: index];
	} else if ([value isKindOfClass:[NSDate class]]) {
		[self bindDate:value atIndex: index];
	} else if ([value isKindOfClass:[NSNumber class]]) {
		[self bindNumber:value atIndex:index];
	} else if ([value isKindOfClass:[NSString class]]) {
		[self bindString:value atIndex:index];
	}
}

- (void)bindNullAtIndex:(int)index {
	int error = sqlite3_bind_null (statement, index);
	if (error != SQLITE_OK) NSLog (@"Error result from sqlite3_bind_null(): %d", error);
}

- (void)bindString:(NSString*)string atIndex:(int)index {
	if (string == nil) {
		[self bindNullAtIndex:index];
	} else {
		const char *s = [string cStringUsingEncoding:NSUTF8StringEncoding];
		int error = sqlite3_bind_text(statement, index, s, -1, SQLITE_TRANSIENT);
		if (error != SQLITE_OK) NSLog (@"Error result from sqlite3_bind_text(): %d", error);
	}
}

- (void)bindNumber:(NSNumber*)number atIndex:(int)index {
	if (number == nil) {
		[self bindNullAtIndex:index];
	} else {
		[self bindDouble:[number doubleValue] atIndex:index];
	}
}

- (void)bindInteger:(SInt64)n atIndex:(int)index {
	int error = sqlite3_bind_int64(statement, index, n);
	if (error != SQLITE_OK) NSLog (@"Error result from sqlite3_bind_int64(): %d", error);
}

- (void)bindDouble:(double)n atIndex:(int)index {
	int error = sqlite3_bind_double(statement, index, n);
	if (error != SQLITE_OK) NSLog (@"Error result from sqlite3_bind_double(): %d", error);
}

- (void)bindDate:(NSDate*)date atIndex:(int)index {
	if (date == nil) {
		[self bindNullAtIndex:index];
	} else {
		// Convert date to number of seconds since reference date.
		SInt64 seconds = round ([date timeIntervalSinceReferenceDate]);
		[self bindInteger:seconds atIndex:index];
	}
}

- (int)step {
	int result = sqlite3_step (statement);
	if (result != SQLITE_DONE && result != SQLITE_ROW && result != SQLITE_OK)
		NSLog (@"Error result from sqlite3_step(): %d", result);
	return result;
}

- (id)objectForColumnIndex:(int)column {
	id result = nil;
	int colType = sqlite3_column_type (statement, column);
	sqlite3_int64 intValue;
	double doubleValue;
	const unsigned char *s;
	
	switch (colType) {
		case SQLITE_INTEGER:
			intValue = sqlite3_column_int64 (statement, column);
			result = [NSNumber numberWithLongLong:intValue];
			break;
		case SQLITE_FLOAT:
			doubleValue = sqlite3_column_double (statement, column);
			result = [NSNumber numberWithDouble:doubleValue];
			break;
		case SQLITE_TEXT:
			s = sqlite3_column_text (statement, column);
			result = [NSString stringWithUTF8String: (char *)s];
			break;
		default:
			break;
	}
	return result;
}

- (NSString *)columnNameAtIndex:(int)index {
	const char *s = sqlite3_column_name (statement, index);
	return [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)rowData {
	int count = sqlite3_column_count (statement);
	id value;
	NSString *key;
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:count];
	for (int index = 0; index < count; index++) {
		value = [self objectForColumnIndex:index];
		key = [self columnNameAtIndex:index];
		if (value != nil && key != nil)
			[result setObject:value forKey:key];
	}
	return result;
}

- (void)reset {
	int error = sqlite3_reset (statement);
	if (error != SQLITE_OK) NSLog (@"Error result from sqlite3_reset(): %d", error);
}

- (void)dealloc {
	int error = sqlite3_finalize (statement);
	if (error != SQLITE_OK) NSLog (@"Error result from sqlite3_finalize(): %d", error);
	
	[super dealloc];
}

@end
