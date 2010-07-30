//
//  TwitterDirectMessageTimeline.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterDirectMessageTimeline.h"
#import "TwitterDirectMessage.h"
#import "TwitterLoadDirectMessagesAction.h"
#import "TwitterLoadTimelineAction.h"
#import "LKSqliteDatabase.h"


// Constants for filter in directMessagesWithLimit
enum {
	kAllMessages = 0,
	kSentMessagesOnly = 1,
	kReceivedMessagesOnly = 2
};


@implementation TwitterDirectMessageTimeline

- (void)dealloc {
	[super dealloc];
}

- (void)setDatabase:(LKSqliteDatabase *)db tableName:(NSString*)tableName temp:(BOOL)temp {
	if (database != db) {
		[database release];
		database = [db retain];
	}
	if (databaseTableName != tableName) {
		[databaseTableName release];
		databaseTableName = [tableName copy];
	}
	
	NSString *tempString = temp? @"temp" : @"";
	NSString *query = [NSString stringWithFormat:@"Create %@ table if not exists %@ (identifier integer primary key, createdDate integer, gapAfter boolean, sent boolean, Foreign Key (identifier) references DirectMessages(identifier))", tempString, databaseTableName];
	[database execute:query];
}

- (NSArray *)directMessagesWithLimit:(int)limit filter:(int)filter {
	// SQL command to select rows up to limit sorted by createdDate.
	if (limit <= 0) return nil;
	if (database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	NSString *where = nil;
	switch (filter) {
		case kSentMessagesOnly:
			where = [NSString stringWithFormat:@"where %@.sent == 1", databaseTableName];
			break;
		case kReceivedMessagesOnly:
			where = [NSString stringWithFormat:@"where %@.sent == 0", databaseTableName];
			break;
		default:
			where = @"";
			break;
	}
	
	NSString *query = [NSString stringWithFormat:@"Select DirectMessages.* from DirectMessages inner join %@ on %@.identifier=DirectMessages.identifier %@ order by DirectMessages.CreatedDate desc limit %d", databaseTableName, databaseTableName, where, limit];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	NSMutableArray *messages = [NSMutableArray arrayWithCapacity:limit];
	TwitterDirectMessage *message;
	
	while ([statement step] == SQLITE_ROW) { // Row has data.
		message = [[[TwitterDirectMessage alloc] initWithDictionary:[statement rowData]] autorelease];
		[messages addObject:message];
	}
	
	return messages;
}

- (NSArray *)messagesWithLimit:(int)limit {
	return [self directMessagesWithLimit:limit filter:kAllMessages];
}

#pragma mark Loading from Twitter servers

- (void)startLoadActionWithFilter:(int)filter {
	// Create our own load action and set up the load count.
	NSString *method = (filter == kSentMessagesOnly)? @"direct_messages/sent" : @"direct_messages";
	TwitterLoadDirectMessagesAction *action = [[[TwitterLoadDirectMessagesAction alloc] initWithTwitterMethod:method] autorelease];
	[action setCount:[self defaultLoadCount]];
	
	// Limit the query to messages newer than what we already have. 
	NSArray *messages = [self directMessagesWithLimit:1 filter:filter];
	if (messages.count > 0) {
		NSNumber *newerThan = [[messages objectAtIndex:0] identifier];
		[action.parameters setObject:newerThan forKey:@"since_id"];
	}
	
	// Prepare action and start it. 
	action.completionTarget= self;
	action.completionAction = @selector(didLoadDirectMessages:);
	[delegate startTwitterAction:action];
}

- (void)reloadNewer {
	// Load messages newer than what we have locally. Since there are actually two separate timelines for direct messages, one for received and one for sent, we need to determine the newest for each timeline separately, and send separate actions for the two timelines.
	// Start both actions at the same time.
	[self startLoadActionWithFilter:kReceivedMessagesOnly];
	[self startLoadActionWithFilter:kSentMessagesOnly];
}

- (void)didLoadDirectMessages:(TwitterLoadTimelineAction *)action {
	// Limit the length of the timeline
	[self limitDatabaseTableSize];
	
	// Call delegate so it can update the UI and Twitter cache.
	if ([delegate respondsToSelector:@selector(timeline:didLoadWithAction:)]) 
		[delegate timeline:self didLoadWithAction:action];
}

@end
