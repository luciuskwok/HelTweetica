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


// Constants for filter in selecting rows.
enum {
	kAllMessages = 0,
	kSentMessagesOnly = 1,
	kReceivedMessagesOnly = 2
};


@implementation TwitterDirectMessageTimeline
@synthesize accountIdentifier, newestSentIdentifier, newestReceivedIdentifier;

- (id)init {
	self = [super init];
	if (self) {
		noOlderMessages = YES;
	}
	return self;
}

- (void)dealloc {
	[accountIdentifier release];
	[newestSentIdentifier release];
	[newestReceivedIdentifier release];
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
	NSMutableArray *messages = [NSMutableArray arrayWithCapacity:limit];
	TwitterDirectMessage *message;
	
	[twitter.database beginTransaction];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	while ([statement step] == SQLITE_ROW) { // Row has data.
		message = [[[TwitterDirectMessage alloc] initWithDictionary:[statement rowData]] autorelease];
		[messages addObject:message];
	}
	[twitter.database endTransaction];
	
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
		int gapAfter = (hasGap && [message isEqual:last])? 1 : 0;

		// Bind variables.
		[statement bindNumber:[message identifier] atIndex:1];
		[statement bindDate:[message createdDate] atIndex:2];
		[statement bindInteger:gapAfter atIndex:3];
		[statement bindInteger:sent? 1:0 atIndex:4];
		
		// Execute and reset.
		[statement step];
		[statement reset];
	}
}

- (NSNumber *)newestStatusIdentifier {
	// This is used only by the unread messages indicator, so only consider received messages.
	NSString *query = [NSString stringWithFormat:@"Select identifier from %@ where sent == 0 order by CreatedDate desc limit 1", databaseTableName];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	NSNumber *n = nil;
	
	if ([statement step] == SQLITE_ROW) { // Row has data.
		n = [statement objectForColumnIndex:0];
	}
	return n;
}

#pragma mark Conversations

- (NSArray *)usersSortedByMostRecentDirectMessage {
	NSMutableArray *users = [NSMutableArray array];
	
	// Get sender and recipient identifiers for rows in this timeline.
	const int kRowCountLimit = 1000;
	NSString *columnsToSelect = @"DirectMessages.senderIdentifier, DirectMessages.recipientIdentifier";
	NSString *query = [NSString stringWithFormat:@"Select %@ from DirectMessages inner join %@ on %@.identifier=DirectMessages.identifier order by DirectMessages.createdDate desc limit %d", columnsToSelect, databaseTableName, databaseTableName, kRowCountLimit];
	NSNumber *sender, *recipient;
	
	[twitter.database beginTransaction];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	while ([statement step] == SQLITE_ROW) { // Row has data.
		// Add all users excluding yourself.
		sender = [statement objectForColumnIndex:0];
		recipient = [statement objectForColumnIndex:1];
		
		if ([sender isEqualToNumber:accountIdentifier] == NO && [users containsObject:sender] == NO && sender != nil) {
			[users addObject:sender];
		} else if ([recipient isEqualToNumber:accountIdentifier] == NO && [users containsObject:recipient] == NO && recipient != nil) {
			[users addObject:recipient];
		}
	}
	[twitter.database endTransaction];
	
	return users;
}

- (NSArray *)directMessagesWithUserIdentifier:(NSNumber *)userIdentifier {
	NSMutableArray *messages = [NSMutableArray array];
	
	// Timing:
	//NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];

	// Get rows where either sender or recipient match the user identifier.
	const int kRowCountLimit = 1000;
	NSString *whereClause = [NSString stringWithFormat:@"where DirectMessages.senderIdentifier == %@ or DirectMessages.recipientIdentifier == %@", [userIdentifier stringValue], [userIdentifier stringValue]];
	NSString *query = [NSString stringWithFormat:@"Select DirectMessages.* from DirectMessages inner join %@ on %@.identifier=DirectMessages.identifier %@ order by DirectMessages.CreatedDate desc limit %d", databaseTableName, databaseTableName, whereClause, kRowCountLimit];
	TwitterDirectMessage *message;
	
	[twitter.database beginTransaction];
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	while ([statement step] == SQLITE_ROW) { // Row has data.
		message = [[[TwitterDirectMessage alloc] initWithDictionary:[statement rowData]] autorelease];
		[messages addObject:message];
	}
	[twitter.database endTransaction];
	
	// Timing:
	//NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
	//NSLog (@"directMessagesWithUserIdentifier read %d rows in %1.2f seconds", messages.count, endTime - startTime);

	return messages;
}

- (NSArray *)messagesWithLimit:(int)limit {
	// Returns an array of direct message groups, which contain user info and a subarray of messages.
	
	// Get the latest direct messages.
	const int kMaxDirectMessagesToShow = 1000;
	NSArray *messages = [self directMessagesWithLimit:kMaxDirectMessagesToShow filter:kAllMessages];
	
	// Group by user.
	NSMutableArray *users = [NSMutableArray array];
	NSMutableArray *conversations = [NSMutableArray array];
	TwitterDirectMessageConversation *conversation;
	
	for (TwitterDirectMessage *message in messages) {
		NSNumber *sender = message.senderIdentifier;
		NSNumber *recipient = message.recipientIdentifier;
		
		if ([sender isEqualToNumber:accountIdentifier] == NO && sender != nil) {
			if ([users containsObject:sender] == NO) {
				[users addObject:sender];
				conversation = [[[TwitterDirectMessageConversation alloc] initWithUserIdentifier:sender] autorelease];
				[conversations addObject:conversation];
			} else {
				conversation = [conversations objectAtIndex:[users indexOfObject:sender]];
			}
			[conversation.messages addObject:message];
		} else if ([recipient isEqualToNumber:accountIdentifier] == NO && recipient != nil) {
			if ([users containsObject:recipient] == NO) {
				[users addObject:recipient];
				conversation = [[[TwitterDirectMessageConversation alloc] initWithUserIdentifier:recipient] autorelease];
				[conversations addObject:conversation];
			} else {
				conversation = [conversations objectAtIndex:[users indexOfObject:recipient]];
			}
			[conversation.messages addObject:message];
		}
	}
	
	return conversations;
}


#pragma mark Loading from Twitter servers

- (void)startLoadActionWithFilter:(int)filter since:(NSNumber *)since {
	// Create our own load action and set up the load count.
	BOOL sent = (filter == kSentMessagesOnly);
	NSString *method = sent? @"direct_messages/sent" : @"direct_messages";
	TwitterLoadDirectMessagesAction *action = [[[TwitterLoadDirectMessagesAction alloc] initWithTwitterMethod:method] autorelease];
	[action setCount:[self defaultLoadCount]];
	
	// Limit the query to messages newer than what we already have. 
	if (since) {
		[action.parameters setObject:since forKey:@"since_id"];
	}
	
	// Prepare action and start it. 
	action.completionTarget= self;
	action.completionAction = @selector(didLoadDirectMessages:);
	[twitter startTwitterAction:action withAccount:account];
}

- (NSNumber *)newestIdentifierWithFilter:(int)filter {
	if (twitter.database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	NSNumber *identifier = nil;
	int sent = (filter == kSentMessagesOnly)? 1: 0;
	
	NSString *query = [NSString stringWithFormat:@"Select identifier from %@ where sent == %d order by createdDate desc limit 1", databaseTableName, sent];
	
	LKSqliteStatement *statement = [twitter.database statementWithQuery:query];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		identifier = [statement objectForColumnIndex:0];
	}
	
	return identifier;
}

- (void)reloadNewer {
	// Load messages newer than what we have locally. Since there are actually two separate timelines for direct messages, one for received and one for sent, we need to determine the newest for each timeline separately, and send separate actions for the two timelines.
	
	// Get the latest sent and received messages.
	if (newestReceivedIdentifier == nil) {
		self.newestReceivedIdentifier = [self newestIdentifierWithFilter:kReceivedMessagesOnly];
	}
	if (newestSentIdentifier == nil) {
		self.newestSentIdentifier = [self newestIdentifierWithFilter:kSentMessagesOnly];
	}
	
	// Start both actions at the same time.
	[self startLoadActionWithFilter:kReceivedMessagesOnly since:newestReceivedIdentifier];
	[self startLoadActionWithFilter:kSentMessagesOnly since:newestSentIdentifier];
}

- (void)didLoadDirectMessages:(TwitterLoadTimelineAction *)action {
	//Testing:
	//NSLog (@"didLoadDirectMessages: %d messages for %@/%@", action.loadedMessages.count, account.screenName, action.twitterMethod);

	if (action.loadedMessages.count > 0) {
		// Latest message
		BOOL sent = [action.twitterMethod hasSuffix:@"sent"];
		TwitterDirectMessage *newestMessage = [action.loadedMessages objectAtIndex:0];
		if (sent) {
			self.newestSentIdentifier = newestMessage.identifier;
		} else {
			self.newestReceivedIdentifier = newestMessage.identifier;
		}
		
		[twitter.database beginTransaction];

		// Update Twitter cache.
		[twitter addDirectMessages:action.loadedMessages];
		[twitter addOrReplaceUsers:action.users];
		
		// Update timeline.
		[self addMessages:action.loadedMessages sent:sent];

		// Limit the length of the timeline
		[self limitDatabaseTableSize];
		[twitter.database endTransaction];
	}
	
	// Update display.
	[[NSNotificationCenter defaultCenter] postNotificationName:TwitterTimelineDidFinishLoadingNotification object:self userInfo:nil];
}


@end
