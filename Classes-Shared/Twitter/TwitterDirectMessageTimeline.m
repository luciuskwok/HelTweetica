//
//  TwitterDirectMessageTimeline.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterDirectMessageTimeline.h"
#import "TwitterDirectMessage.h"
#import "TwitterDirectMessageConversation.h"
#import "TwitterLoadDirectMessagesAction.h"
#import "TwitterLoadTimelineAction.h"
#import "Twitter.h"


// Constants for filter in directMessagesWithLimit
enum {
	kAllMessages = 0,
	kSentMessagesOnly = 1,
	kReceivedMessagesOnly = 2
};


@implementation TwitterDirectMessageTimeline
@synthesize accountIdentifier;


- (void)dealloc {
	[accountIdentifier release];
	[super dealloc];
}

#pragma mark Database

- (void)setTwitter:(Twitter *)aTwitter tableName:(NSString*)tableName temp:(BOOL)temp {
	self.twitter = aTwitter;
	self.databaseTableName = tableName;
	
	NSString *tempString = temp? @"temp" : @"";
	NSString *query = [NSString stringWithFormat:@"Create %@ table if not exists %@ (identifier integer primary key, createdDate integer, gapAfter boolean, sent boolean, Foreign Key (identifier) references DirectMessages(identifier))", tempString, databaseTableName];
	[twitter.database execute:query];
}

- (NSArray *)directMessagesWithLimit:(int)limit filter:(int)filter {
	// SQL command to select rows up to limit sorted by createdDate.
	if (limit <= 0) return nil;
	if (twitter.database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	NSString *whereClause = nil;
	switch (filter) {
		case kSentMessagesOnly:
			whereClause = [NSString stringWithFormat:@"where %@.sent == 1", databaseTableName];
			break;
		case kReceivedMessagesOnly:
			whereClause = [NSString stringWithFormat:@"where %@.sent == 0", databaseTableName];
			break;
		default:
			whereClause = @"";
			break;
	}
	
	NSString *query = [NSString stringWithFormat:@"Select DirectMessages.* from DirectMessages inner join %@ on %@.identifier=DirectMessages.identifier %@ order by DirectMessages.createdDate desc limit %d", databaseTableName, databaseTableName, whereClause, limit];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	NSMutableArray *messages = [NSMutableArray arrayWithCapacity:limit];
	TwitterDirectMessage *message;
	
	while ([statement step] == SQLITE_ROW) { // Row has data.
		message = [[[TwitterDirectMessage alloc] initWithDictionary:[statement rowData]] autorelease];
		[messages addObject:message];
	}
	
	return messages;
}

- (void)addMessages:(NSArray *)messages sent:(BOOL)sent {
	if (messages.count == 0) return;
	if (twitter.database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	// Check if oldest message exists in timeline.
	id last = [messages lastObject];
	BOOL hasGap = ([self containsIdentifier:[last identifier]] == NO);
	
	// Insert or replace rows. Rows with the same identifier will be replaced with the new one.
	NSArray *allKeys = [NSArray arrayWithObjects:@"identifier", @"createdDate", @"gapAfter", @"sent", nil];
	NSString *query = [twitter.database queryWithCommand:@"Insert or replace into" table:databaseTableName keys:allKeys];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	
	for (id message in messages) {
		// Bind variables.
		[statement bindNumber:[message identifier] atIndex:1];
		[statement bindDate:[message createdDate] atIndex:2];
		[statement bindInteger:sent? 1:0 atIndex:3];
		
		int gapAfter = (hasGap && [message isEqual:last])? 1 : 0;
		[statement bindInteger:gapAfter atIndex:3];
		
		// Execute and reset.
		[statement step];
		[statement reset];
	}
	
}

#pragma mark Conversations

- (NSArray *)usersSortedByMostRecentDirectMessage {
	NSMutableArray *users = [NSMutableArray array];
	
	// Get sender and recipient identifiers for rows in this timeline.
	const int kRowCountLimit = 1000;
	NSString *columnsToSelect = @"DirectMessages.senderIdentifier, DirectMessages.recipientIdentifier";
	NSString *query = [NSString stringWithFormat:@"Select %@ from DirectMessages inner join %@ on %@.identifier=DirectMessages.identifier order by DirectMessages.createdDate desc limit %d", columnsToSelect, databaseTableName, databaseTableName, kRowCountLimit];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	NSNumber *sender, *recipient;
	
	while ([statement step] == SQLITE_ROW) { // Row has data.
		// Add all users excluding yourself.
		sender = [statement objectForColumnIndex:0];
		recipient = [statement objectForColumnIndex:1];
		
		if ([sender isEqualToNumber:accountIdentifier] == NO && [users containsObject:sender] == NO) {
			[users addObject:sender];
		} else if ([recipient isEqualToNumber:accountIdentifier] == NO && [users containsObject:recipient] == NO) {
			[users addObject:recipient];
		}
	}
	
	return users;
}

- (NSArray *)directMessagesWithUserIdentifier:(NSNumber *)userIdentifier {
	NSMutableArray *messages = [NSMutableArray array];
	
	// Get rows where either sender or recipient match the user identifier.
	const int kRowCountLimit = 1000;
	NSString *whereClause = [NSString stringWithFormat:@"where DirectMessages.senderIdentifier == %@ or DirectMessages.recipientIdentifier == %@", [userIdentifier stringValue], [userIdentifier stringValue]];
	NSString *query = [NSString stringWithFormat:@"Select DirectMessages.* from DirectMessages inner join %@ on %@.identifier=DirectMessages.identifier %@ order by DirectMessages.createdDate desc limit %d", databaseTableName, databaseTableName, whereClause, kRowCountLimit];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	TwitterDirectMessage *message;
	
	while ([statement step] == SQLITE_ROW) { // Row has data.
		message = [[[TwitterDirectMessage alloc] initWithDictionary:[statement rowData]] autorelease];
		[messages addObject:message];
	}
	
	return messages;
}

- (NSArray *)messagesWithLimit:(int)limit {
	// Returns an array of direct message groups, which contain user info and a subarray of messages.
	
	// Get array of users sorted by most recent direct message, and create a sorted list of conversations with it.
	NSArray *sortedUsers = [self usersSortedByMostRecentDirectMessage];
	NSMutableArray *conversations = [NSMutableArray array];
	for (NSNumber *user in sortedUsers) {
		TwitterDirectMessageConversation *conversation = [[[TwitterDirectMessageConversation alloc] init] autorelease];
		conversation.user = user;
		conversation.messages = [self directMessagesWithUserIdentifier:user];
		[conversations addObject:conversation];
	}
	
	return conversations;
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
	[twitter startTwitterAction:action withAccount:account];
}

- (void)reloadNewer {
	// Load messages newer than what we have locally. Since there are actually two separate timelines for direct messages, one for received and one for sent, we need to determine the newest for each timeline separately, and send separate actions for the two timelines.
	// Start both actions at the same time.
	[self startLoadActionWithFilter:kReceivedMessagesOnly];
	[self startLoadActionWithFilter:kSentMessagesOnly];
}

- (void)didLoadDirectMessages:(TwitterLoadTimelineAction *)action {
	// Begin transaction.
	[twitter.database beginTransaction];
	
	// Limit the length of the timeline
	[self limitDatabaseTableSize];

	// Update Twitter cache.
	[twitter addDirectMessages:action.loadedMessages];
	[twitter addOrReplaceUsers:action.users];
	
	// Update timeline.
	BOOL sent = [action.twitterMethod hasSuffix:@"sent"];
	[self addMessages:action.loadedMessages sent:sent];

	// End transaction.
	[twitter.database endTransaction];
	
	// Update display.
	[[NSNotificationCenter defaultCenter] postNotificationName:TwitterTimelineDidFinishLoadingNotification object:self userInfo:nil];
}


@end
