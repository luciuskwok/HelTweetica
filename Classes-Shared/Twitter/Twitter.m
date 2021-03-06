//
//  Twitter.m
//  HelTweetica
//
//  Created by Lucius Kwok on 3/30/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "Twitter.h"
#import "TwitterTimeline.h"
#import "TwitterUserInfoAction.h"
#import "HelTweeticaAppDelegate.h"



// HelTweetica twitter consumer/client credentials.
// Please use your own application credentials, which you can request from Twitter.

// You will need to supply your own credentials in the file imported here:
#import "(HelTweeticaConsumerToken).h"
// The file shoud contain the following two lines:
// #define kConsumerKey @"xxxxxxxxxxxxxxxx"
// #define kConsumerSecret @"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

// Refresh
const NSTimeInterval kRefreshTimerInterval = 60.0;


@implementation Twitter
@synthesize accounts, database;


- (id) init {
	if (self = [super init]) {
		self.accounts = [NSMutableArray array];
		actions = [[NSMutableSet alloc] init];

		// == Sqlite 3 ==
		// Create a new sqlite database if none exists.
		NSArray *paths = NSSearchPathForDirectoriesInDomains (NSCachesDirectory, NSUserDomainMask, YES);
		NSString *cachePath = [paths objectAtIndex:0];
		NSString *cacheFile = [cachePath stringByAppendingPathComponent:@"HelTweetica Twitter Cache.db"];
		//BOOL justCreated = ![[NSFileManager defaultManager] fileExistsAtPath:cacheFile];
		database = [[LKSqliteDatabase alloc] initWithFile:cacheFile];
		
		// Create tables and indexes if they don't exist.
		NSError *error = nil;
		NSString *creationPath = [[NSBundle mainBundle] pathForResource:@"SqliteInit" ofType:@"sql"];
		NSString *initStatement = [NSString stringWithContentsOfFile:creationPath encoding:NSUTF8StringEncoding error:&error];
		if (initStatement == nil) {
			NSLog (@"Unable to SQL statements for init. %@", [error localizedDescription]);
		} else {
			[database execute:initStatement];
		}
		
		// == User defaults ==
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// Remove old preferences if they exist, to free up disk space.
		[defaults removeObjectForKey:@"twitterAccounts"];
		[defaults removeObjectForKey:@"twitterUsers"];
		
		// Load account info from user defaults
		NSData *data = [defaults objectForKey:@"allAccounts"];
		if (data != nil)
			self.accounts = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		// Set up the database connections.
		for (TwitterAccount *account in accounts) 
			[account setTwitter:self];
		
		// == Refresh timer ==
		[self performSelector:@selector(refreshNow) withObject:nil afterDelay:5.0];
	}
	return self;
}

- (void) dealloc {
	[accounts release];
	[database release];
	[actions release];
	[refreshTimer invalidate];
	[super dealloc];
}

#pragma mark Accounts

- (TwitterAccount*) accountWithScreenName: (NSString*) screenName {
	for (TwitterAccount *account in accounts) {
		if ([account.screenName caseInsensitiveCompare: screenName] == NSOrderedSame)
			return account;
	}
	return nil;
}

- (void) moveAccountAtIndex:(int)fromIndex toIndex:(int)toIndex {
	id item = [[accounts objectAtIndex:fromIndex] retain];
	[accounts removeObjectAtIndex:fromIndex];
	[accounts insertObject:item atIndex:toIndex];
	[item release];
}

#pragma mark Status Updates

- (void)addStatusUpdates:(NSArray *)newUpdates replaceExisting:(BOOL)replace {
	if (newUpdates.count == 0) return;

	// Insert or replace rows. Rows with the same identifier will be replaced with the new one.
	NSArray *allKeys = [TwitterStatusUpdate databaseKeys];
	NSString *onConflict = replace? @"replace" : @"ignore";
	NSString *command = [NSString stringWithFormat:@"Insert or %@ into", onConflict];
	NSString *query = [database queryWithCommand:command table:@"StatusUpdates" keys:allKeys];
	LKSqliteStatement *statement = [database statementWithQuery:query];

	for (TwitterStatusUpdate *status in newUpdates) {
		if ([status isKindOfClass:[TwitterStatusUpdate class]]) {
			// Sanity check.
			if (status.identifier == nil || status.text == nil) 
				continue;
			
			// Bind variables.
			for (int index = 0; index<allKeys.count; index++) {
				id key = [allKeys objectAtIndex:index];
				NSString *value = [status databaseValueForKey:key];
				[statement bindValue:value atIndex:index+1];
			}
			
			// Execute and reset.
			[statement step];
			[statement reset];
		}
	}
}


- (TwitterStatusUpdate *)statusUpdateWithIdentifier:(NSNumber *)identifier {
	if ([identifier longLongValue] == 0) return nil;

	TwitterStatusUpdate *status = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"SELECT * FROM StatusUpdates WHERE identifier == ?"];
	[statement bindNumber:identifier atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		status = [[[TwitterStatusUpdate alloc] initWithDictionary:[statement rowData]] autorelease];
	}
	return status;
}

- (NSSet*) statusUpdatesInReplyToStatusIdentifier:(NSNumber*)identifier {
	if ([identifier longLongValue] == 0) return nil;

	NSMutableSet *resultSet = [NSMutableSet set];
	TwitterStatusUpdate *status = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"SELECT * FROM StatusUpdates WHERE inReplyToStatusIdentifier == ?"];
	[statement bindNumber:identifier atIndex:1];
	while ([statement step] == SQLITE_ROW) { // Row has data.
		status = [[[TwitterStatusUpdate alloc] initWithDictionary:[statement rowData]] autorelease];
		[resultSet addObject:status]; 
	}
	return resultSet;
}

- (void)deleteStatusUpdate:(NSNumber*)anIdentifier {
	if ([anIdentifier longLongValue] == 0) return;

	// Remove all references to this status update.
	for (TwitterAccount *account in accounts) {
		[account deleteStatusUpdate:anIdentifier];
	}
	
	// SQLite statement to delete status update from tables.
	NSString *query = @"Delete from StatusUpdates where Identifier == ?";
	LKSqliteStatement *statement = [database statementWithQuery:query];
	[statement bindNumber:anIdentifier atIndex:1];
	int result = [statement step];
	if (result != SQLITE_OK && result != SQLITE_DONE) {
		NSLog (@"SQLite error deleting row: %d", result);
	}
}

#pragma mark Direct Messages

- (void)addDirectMessages:(NSArray *)newMessages {
	if (newMessages.count == 0) return;
	
	// Insert or replace rows. Rows with the same identifier will be replaced with the new one.
	NSArray *allKeys = [TwitterDirectMessage databaseKeys];
	NSString *query = [database queryWithCommand:@"Insert or replace into" table:@"DirectMessages" keys:allKeys];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	
	for (TwitterDirectMessage *message in newMessages) {
		if ([message isKindOfClass:[TwitterDirectMessage class]]) {
			// Bind variables.
			for (int index = 0; index<allKeys.count; index++) {
				id key = [allKeys objectAtIndex:index];
				NSString *value = [message databaseValueForKey:key];
				[statement bindValue:value atIndex:index+1];
			}
			
			// Execute and reset.
			[statement step];
			[statement reset];
		}
	}
}

- (TwitterDirectMessage *)directMessageWithIdentifier:(NSNumber *)identifier {
	if ([identifier longLongValue] == 0) return nil;
	
	TwitterDirectMessage *status = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"SELECT * FROM DirectMessages WHERE identifier == ?"];
	[statement bindNumber:identifier atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		status = [[[TwitterDirectMessage alloc] initWithDictionary:[statement rowData]] autorelease];
	}
	return status;
}

#pragma mark Users

- (void)addUsers:(NSSet *)newUsers {
	if (newUsers.count == 0) return;
	
	// Insert rows. Users with the same identifier will not be inserted.
	NSArray *allKeys = [TwitterUser databaseKeys];
	NSString *query = [database queryWithCommand:@"Insert or ignore into" table:@"Users" keys:allKeys];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	
	for (TwitterUser *user in newUsers) {
		if ([user isKindOfClass:[TwitterUser class]]) {
			// Sanity check.
			if (user.identifier == nil || user.screenName == nil)
				continue;
			
			// Bind variables.
			for (int index = 0; index<allKeys.count; index++) {
				id key = [allKeys objectAtIndex:index];
				NSString *value = [user databaseValueForKey:key];
				[statement bindValue:value atIndex:index+1];
			}
			
			// Execute and reset.
			[statement step];
			[statement reset];
		}
	}
}

- (void)addOrReplaceUsers:(NSSet *)newUsers {
	if (newUsers.count == 0) return;
	
	// Insert or replace rows. Rows with the same user identifier will be replaced with the new one.
	NSArray *allKeys = [TwitterUser databaseKeys];
	NSString *query = [database queryWithCommand:@"Insert or replace into" table:@"Users" keys:allKeys];
	LKSqliteStatement *statement = [database statementWithQuery:query];
	
	for (TwitterUser *user in newUsers) {
		// Sanity check.
		if (user.identifier == nil || user.screenName == nil)
			continue;

		// Bind variables.
		for (int index = 0; index<allKeys.count; index++) {
			id key = [allKeys objectAtIndex:index];
			NSString *value = [user databaseValueForKey:key];
			[statement bindValue:value atIndex:index+1];
		}
		
		// Execute and reset.
		[statement step];
		[statement reset];
	}
}

- (TwitterUser *)userWithScreenName:(NSString *)screenName {
	TwitterUser *user = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"Select * from Users where ScreenName like ?"];
	[statement bindString:screenName atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		user = [[[TwitterUser alloc] initWithDictionary:[statement rowData]] autorelease];
	}
	return user;
}

- (TwitterUser *)userWithIdentifier:(NSNumber *)identifier {
	if ([identifier longLongValue] == 0) return nil;
	
	TwitterUser *user = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"Select * from Users where Identifier == ?"];
	[statement bindNumber:identifier atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		user = [[[TwitterUser alloc] initWithDictionary:[statement rowData]] autorelease];
	}
	return user;
}

- (NSArray *)allUsers {
	NSMutableArray *set = [NSMutableArray arrayWithCapacity:1000];
	TwitterUser *user = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"Select * from Users order by ScreenName collate nocase asc limit 1000"];
	while ([statement step] == SQLITE_ROW) { // Row has data.
		user = [[[TwitterUser alloc] initWithDictionary:[statement rowData]] autorelease];
		[set addObject:user];
	}
	return set;
}

- (NSArray *)usersWithName:(NSString *)name {
	NSMutableArray *set = [NSMutableArray arrayWithCapacity:1000];
	TwitterUser *user = nil;
	NSString *pattern = [NSString stringWithFormat:@"%%%@%%", name];
	LKSqliteStatement *statement = [database statementWithQuery:@"Select * from Users where ScreenName like ? union Select * from Users where FullName like ? order by ScreenName collate nocase asc limit 1000"];
	[statement bindString:pattern atIndex:1];
	[statement bindString:pattern atIndex:2];
	while ([statement step] == SQLITE_ROW) { // Row has data.
		user = [[[TwitterUser alloc] initWithDictionary:[statement rowData]] autorelease];
		[set addObject:user];
	}
	return set;
}

#pragma mark TwitterActions

- (void)startTwitterAction:(TwitterAction *)action withAccount:(TwitterAccount *)account {
	[actions addObject:action];
	[[HelTweeticaAppDelegate sharedAppDelegate] incrementNetworkActionCount];

	// Set up Twitter action
	[action setDelegate: self];
	if (account) {
		[action setConsumerToken: account.xAuthToken];
		[action setConsumerSecret: account.xAuthSecret];
	}
	
	// Start the URL connection
	[action start];
}

- (void)removeAction:(id)action {
	[[HelTweeticaAppDelegate sharedAppDelegate] decrementNetworkActionCount];
	[actions removeObject: action];
}

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	[self removeAction: action];
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	[[NSNotificationCenter defaultCenter] postNotificationName:TwitterErrorNotification object:error];
	[self removeAction: action];
}


#pragma mark Profile images

- (void)loadProfileImageURL:(NSString *)url withAccount:(TwitterAccount *)account {
	if (url == nil)
		return;
	if (account.profileImageURL != nil) {
		if ([url isEqualToString:account.profileImageURL])
			return; // Don't reload the profile image if the url is the same.
	}
	
	// Start an action to load the url.
	LKLoadURLAction *action = [[[LKLoadURLAction alloc] initWithURL:[NSURL URLWithString:url]] autorelease];
	action.delegate = self;
	action.identifier = account.screenName;
	[action start];
	[actions addObject:action];
	[[HelTweeticaAppDelegate sharedAppDelegate] incrementNetworkActionCount];
}

- (void)loadURLAction:(LKLoadURLAction*)action didLoadData:(NSData*)data {
	if (data.length > 0) {
		TwitterAccount *account = [self accountWithScreenName:action.identifier];
		account.profileImageURL = [action.url absoluteString];
		account.profileImageData = data;
	}
	[self removeAction:action];
}

- (void)loadURLAction:(LKLoadURLAction*)action didFailWithError:(NSError*)error {
	[self removeAction:action];
}

- (void)loadUserInfoForAccount:(TwitterAccount *)account {
	TwitterUserInfoAction *action = [[[TwitterUserInfoAction alloc] initWithScreenName:account.screenName] autorelease];
	action.completionAction = @selector(didLoadUserInfo:);
	action.completionTarget = self;
	[self startTwitterAction:action withAccount:account];
}

- (void)didLoadUserInfo:(TwitterUserInfoAction*)action {
	// Update just the profile image.
	NSString *url = action.userResult.profileImageURL;
	TwitterAccount *account = [self accountWithScreenName:action.userResult.screenName];
	[self loadProfileImageURL:url withAccount:account];
}

- (void)loadAccountProfileImages {
	for (TwitterAccount *account in accounts) {
		TwitterUser *user = [self userWithIdentifier:account.identifier];
		if (user.profileImageURL == nil) {
			// Load user info
			[self loadUserInfoForAccount:account];
		} else {
			// Load profile image data
			[self loadProfileImageURL:user.profileImageURL withAccount:account];
		}
	}
}


#pragma mark Refresh timer

- (void)fireRefreshTimer:(NSTimer *)timer {
	if (refreshCount <= 0) {
		// Refresh all only once every three times.
		for (TwitterAccount *account in accounts) {
			[account reloadNewer];
		}
		refreshCount = 3;
		
		// Also update account profile images
		[self loadAccountProfileImages];
	} else {
		for (TwitterAccount *account in accounts) {
			[account.homeTimeline reloadNewer];
		}
		refreshCount--;
	}
}

- (void)refreshNow {
	refreshCount = 0;
	[self fireRefreshTimer:refreshTimer];
	[self scheduleRefreshTimer:kRefreshTimerInterval];
}

- (void)scheduleRefreshTimer:(NSTimeInterval)interval {
	[refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:kRefreshTimerInterval target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:YES];
}

#pragma mark User defaults

- (void) saveUserDefaults {
	// Save only twitter account info
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.accounts];
	[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"allAccounts"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
