//
//  TwitterTimeline.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TwitterTimeline.h"
#import "TwitterStatusUpdate.h"
#import "TwitterDirectMessage.h"
#import "TwitterLoadTimelineAction.h"
#import "LKSqliteDatabase.h"


/*	This class stores its data in a database table with columns for: 
		identifier: message identifier, both primary key and foreign key.
		createdDate: duplicated in this table for sorting purposes.
		gapAfter: flag which indicates that there's a gap in the timeline after this message.
 
 */

// Constants
enum { kMaxNumberOfMessagesInATimeline = 2000 };
// When reloading a timeline, newly downloaded messages are merged with existing ones, sorted by identifier, and the oldest ones past this limit are trimmed off.


@implementation TwitterTimeline
@synthesize noOlderMessages, loadAction, delegate;
//@synthesize twitter;

- (id)init {
	self = [super init];
	if (self) {
	}
	return self;
}

- (void)dealloc {
	[database release];
	[databaseTableName release];
	[loadAction release];
	[super dealloc];
}

#pragma mark Database

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
	NSString *query = [NSString stringWithFormat:@"Create %@ table if not exists %@ (identifier integer primary key, createdDate integer, gapAfter boolean, Foreign Key (identifier) references StatusUpdates(identifier))", tempString, databaseTableName];
	[database execute:query];
}

- (void)deleteCaches {
	NSString *query = [NSString stringWithFormat:@"Drop table if exists %@", databaseTableName];
	[database execute:query];
}

#pragma mark Status Updates

- (void)addMessages:(NSArray*)messages {
	[self addMessages:messages updateGap:NO];
}

- (void)addMessages:(NSArray*)messages updateGap:(BOOL)updateGap {
	if (messages.count == 0) return;
	if (database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	// Check if oldest message exists in timeline.
	id last = [messages lastObject];
	BOOL hasGap = ([self containsIdentifier:[last identifier]] == NO);
	
	// Insert or replace rows. Rows with the same identifier will be replaced with the new one.
	NSArray *allKeys = [NSArray arrayWithObjects:@"identifier", @"createdDate", @"gapAfter", nil];
	NSString *query = [database queryWithCommand:@"Insert or replace into" table:databaseTableName keys:allKeys];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	
	for (id message in messages) {
		// Bind variables.
		[statement bindNumber:[message identifier] atIndex:1];
		[statement bindDate:[message createdDate] atIndex:2];
		
		int gapAfter = (updateGap && hasGap && [message isEqual:last])? 1 : 0;
		[statement bindInteger:gapAfter atIndex:3];
		
		// Execute and reset.
		[statement step];
		[statement reset];
	}
	
}

- (void)removeIdentifier:(NSNumber *)identifier {
	// SQL command to remove row matching message from this timeline only.
	if ([identifier longLongValue] == 0) return;
	
	NSString *query = [NSString stringWithFormat:@"Delete from %@ where Identifier == ?", databaseTableName];
	[database execute:query];
}

- (BOOL)containsIdentifier:(NSNumber *)identifier {
	// SQL command to check for existence of row with matching message identifier for this timeline only.
	if ([identifier longLongValue] == 0) return NO;
	if (database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	NSString *query = [NSString stringWithFormat:@"Select identifier from %@ where Identifier == ?", databaseTableName];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	[statement bindNumber:identifier atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		return YES;
	}
	return NO;
}

- (void)limitTimelineLength:(int)maxLength {
	// SQL command to remove oldest rows sorted by createdDate to keep timeline to maxLength.
}	

- (NSArray *)statusUpdatesWithLimit:(int)limit {
	// SQL command to select rows up to limit sorted by createdDate.
	if (limit <= 0) return nil;
	if (database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	NSString *query = [NSString stringWithFormat:@"Select StatusUpdates.* from StatusUpdates inner join %@ on %@.identifier=StatusUpdates.identifier order by StatusUpdates.CreatedDate desc limit %d", databaseTableName, databaseTableName, limit];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	NSMutableArray *statuses = [NSMutableArray arrayWithCapacity:limit];
	TwitterStatusUpdate *status;
	
	while ([statement step] == SQLITE_ROW) { // Row has data.
		status = [[[TwitterStatusUpdate alloc] initWithDictionary:[statement rowData]] autorelease];
		[statuses addObject:status];
	}
	
	return statuses;
}

- (NSArray *)directMessagesWithLimit:(int)limit {
	// SQL command to select rows up to limit sorted by createdDate.
	if (limit <= 0) return nil;
	if (database == nil)
		NSLog(@"TwitterTimeline is missing its database connection.");
	
	NSString *query = [NSString stringWithFormat:@"Select DirectMessages.* from DirectMessages inner join %@ on %@.identifier=DirectMessages.identifier order by DirectMessages.CreatedDate desc limit %d", databaseTableName, databaseTableName, limit];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	NSMutableArray *messages = [NSMutableArray arrayWithCapacity:limit];
	TwitterDirectMessage *message;
	
	while ([statement step] == SQLITE_ROW) { // Row has data.
		message = [[[TwitterDirectMessage alloc] initWithDictionary:[statement rowData]] autorelease];
		[messages addObject:message];
	}
	
	return messages;
}

- (BOOL)hasGapAfter:(NSNumber *)identifier {
	// SQL to check if message in timeline has the gapAfter flag set.
	if ([identifier longLongValue] == 0) return NO;

	NSString *query = [NSString stringWithFormat:@"Select gapAfter from %@ where Identifier == ?", databaseTableName];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	[statement bindNumber:identifier atIndex:1];
	BOOL hasGap = NO;
	
	if ([statement step] == SQLITE_ROW) { // Row has data.
		NSNumber *n = [statement objectForColumnIndex:0];
		hasGap = [n boolValue];
	}
	return hasGap;
}

- (int)numberOfStatusUpdates {
	NSString *query = [NSString stringWithFormat:@"Select Count(*) from %@", databaseTableName];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	NSNumber *n = nil;
	
	if ([statement step] == SQLITE_ROW) { // Row has data.
		n = [statement objectForColumnIndex:0];
	}
	return [n intValue];
}

- (NSNumber *)oldestStatusIdentifier {
	NSString *query = [NSString stringWithFormat:@"Select identifier from %@ order by CreatedDate asc limit 1", databaseTableName];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	NSNumber *n = nil;
	
	if ([statement step] == SQLITE_ROW) { // Row has data.
		n = [statement objectForColumnIndex:0];
	}
	return n;
}

- (NSNumber *)newestStatusIdentifier {
	NSString *query = [NSString stringWithFormat:@"Select identifier from %@ order by CreatedDate desc limit 1", databaseTableName];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	NSNumber *n = nil;
	
	if ([statement step] == SQLITE_ROW) { // Row has data.
		n = [statement objectForColumnIndex:0];
	}
	return n;
}

#pragma mark Loading

- (void)reloadNewer {
	TwitterLoadTimelineAction *action = self.loadAction;
	if (action == nil) return; // No action to reload.
	
	// Reset "since_id" and "max_id" parameters in case it was set from previous uses.
	[action.parameters removeObjectForKey:@"max_id"];
	[action.parameters removeObjectForKey:@"since_id"];
	
	if ([action.twitterMethod isEqualToString:@"favorites"] == NO) { // Only do this for non-Favorites timelines
		// Set the since_id parameter if there already are messages in the current timeline, except for the favorites timeline, because older tweets can be faved.
		NSNumber *newerThan = nil;
		
		// Skip past retweets because account user's own RTs don't show up in the home timeline.
		int messageIndex = 0;
		TwitterStatusUpdate *message;
		NSArray *messages = [self statusUpdatesWithLimit:50];
		
		while (messageIndex < messages.count) {
			message = [messages objectAtIndex:messageIndex];
			messageIndex++;
			if (message.retweetedStatusIdentifier == nil) break;
		}
		// On exit, messageIndex points to the message one index after the first non-RT message.
		
		if (messageIndex < messages.count) {
			message = [messages objectAtIndex:messageIndex];
			newerThan = message.identifier;
		}
		
		if (newerThan)
			[action.parameters setObject:newerThan forKey:@"since_id"];
	}
	
	// Set the default load count. (Note that searches use rpp instead of count, so this will have no effect on search actions.) 
	[action setCount:[self defaultLoadCount]];
	
	// Prepare action and start it. 
	action.completionTarget= self;
	action.completionAction = @selector(didReloadNewer:);
	[delegate startTwitterAction:action];
}

- (void)didReloadNewer:(TwitterLoadTimelineAction *)action {
	// Limit the length of the timeline
	[self limitTimelineLength:kMaxNumberOfMessagesInATimeline];
	
	// Also start an action to load RTs that the account's user has posted within the loaded timeline
	NSNumber *sinceIdentifier = nil;
	if (action.loadedMessages.count > 1) {
		// If any messages were loaded, load RTs that would be mixed in with these tweets.
		sinceIdentifier = [[action.loadedMessages lastObject] identifier];
	} else if ([self numberOfStatusUpdates] > 0) {
		// If no messages were loaded, still load RTs since newest tweet.
		sinceIdentifier = [self newestStatusIdentifier];
	}
	if (sinceIdentifier) {
		[self reloadRetweetsSince:sinceIdentifier toMax:nil];
	}
	
	// Call delegate so it can update the UI and Twitter cache.
	if ([delegate respondsToSelector:@selector(timeline:didLoadWithAction:)]) 
		[delegate timeline:self didLoadWithAction:action];
}

- (void)reloadRetweetsSince:(NSNumber*)sinceIdentifier toMax:(NSNumber*)maxIdentifier {
	// This only works for the user's own home timeline.
	if ([loadAction.twitterMethod isEqualToString:@"statuses/home_timeline"]) {
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/retweeted_by_me"] autorelease];
		if (sinceIdentifier) 
			[action.parameters setObject:sinceIdentifier forKey:@"since_id"];
		if (maxIdentifier) 
			[action.parameters setObject:maxIdentifier forKey:@"max_id"];
		[action setCount:[self defaultLoadCount]];
		
		// Prepare action and start it. 
		action.completionTarget = self;
		action.completionAction = @selector(didReloadRetweets:);
		[delegate startTwitterAction:action];
	}
}

- (void)didReloadRetweets:(TwitterLoadTimelineAction *)action {
	// Call delegate so it can update the UI and Twitter cache.
	if ([delegate respondsToSelector:@selector(timeline:didLoadWithAction:)]) 
		[delegate timeline:self didLoadWithAction:action];
}

- (void)loadOlderWithMaxIdentifier:(NSNumber*)maxIdentifier {
	TwitterLoadTimelineAction *action = self.loadAction;
	if (action == nil) return; // No action to reload.
	
	if (maxIdentifier == nil && [self numberOfStatusUpdates] > 2) { // Load older
		maxIdentifier = [self oldestStatusIdentifier];
	}
	
	if (maxIdentifier)
		[action.parameters setObject:maxIdentifier forKey:@"max_id"];
	
	// Remove "since_id" parameter in case it was set from loading newer messages;
	[action.parameters removeObjectForKey:@"since_id"];
	
	// Prepare action and start it. 
	action.completionTarget= self;
	action.completionAction = @selector(didLoadOlderInCurrentTimeline:);
	[delegate startTwitterAction:action];
}

- (void) didLoadOlderInCurrentTimeline:(TwitterLoadTimelineAction *)action {
	if (action.loadedMessages.count <= 2) { // The one message is the one in the max_id.
		noOlderMessages = YES;
	}
	
	// TODO: load account user's own RTs within the range from max_id in the action to since_id of last tweet in action.messages.
	
	// Limit the length of the timeline
	[self limitTimelineLength:kMaxNumberOfMessagesInATimeline];
	
	// Call delegate so it can update the UI and Twitter cache.
	if ([delegate respondsToSelector:@selector(timeline:didLoadWithAction:)]) 
		[delegate timeline:self didLoadWithAction:action];
}

- (int)defaultLoadCount {
	return 100;
}


@end
