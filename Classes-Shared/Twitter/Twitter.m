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




// HelTweetica twitter consumer/client credentials.
// Please use your own application credentials, which you can request from Twitter.

// You will need to supply your own credentials in the file imported here:
#import "(HelTweeticaConsumerToken).h"
// The file shoud contain the following two lines:
// #define kConsumerKey @"xxxxxxxxxxxxxxxx"
// #define kConsumerSecret @"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"


@implementation Twitter
@synthesize accounts, statuses;


- (id) init {
	if (self = [super init]) {
		self.accounts = [NSMutableArray array];
		self.statuses = [NSMutableSet set];

		// == User defaults ==
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// Remove old preferences if they exist, to free up disk space.
		[defaults removeObjectForKey:@"twitterAccounts"];
		[defaults removeObjectForKey:@"twitterUsers"];
		
		// Load account info from user defaults
		NSData *data = [defaults objectForKey:@"allAccounts"];
		if (data != nil)
			self.accounts = [NSKeyedUnarchiver unarchiveObjectWithData:data];

		// == Sqlite 3 ==
		// Create a new sqlite database if none exists.
		NSArray *paths = NSSearchPathForDirectoriesInDomains (NSCachesDirectory, NSUserDomainMask, YES);
		NSString *cachePath = [paths objectAtIndex:0];
		NSString *cacheFile = [cachePath stringByAppendingPathComponent:@"HelTweetica Twitter Cache.db"];
		BOOL justCreated = ![[NSFileManager defaultManager] fileExistsAtPath:cacheFile];
		database = [[LKSqliteDatabase alloc] initWithFile:cacheFile];
		
		if (justCreated) {
			// Set up tables.
			NSError *error = nil;
			NSString *creationPath = [[NSBundle mainBundle] pathForResource:@"CreationStatement" ofType:@"sql"];
			NSString *creationStatement = [NSString stringWithContentsOfFile:creationPath encoding:NSUTF8StringEncoding error:&error];
			if (creationStatement == nil) {
				NSLog (@"Unable to load SQL statements to create tables. %@", [error localizedDescription]);
			} else {
				[database execute:creationStatement];
			}
		}
	}
	return self;
}

- (void) dealloc {
	[accounts release];
	[statuses release];
	[database release];
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

- (void)addStatusUpdates:(NSArray *)newUpdates {
	if (newUpdates.count == 0) return;
	
	// Insert or replace rows. Rows with the same identifier will be replaced with the new one.
	NSString *query = @"INSERT OR REPLACE INTO StatusUpdates (identifier, createdDate, receivedDate, userIdentifier, userScreenName,   profileImageURL, inReplyToStatusIdentifier, inReplyToUserIdentifier, inReplyToScreenName, text,   source, retweetedStatusIdentifier, locked) VALUES (?, ?, ?, ?, ?,   ?, ?, ?, ?, ?,   ?, ?, ?)";
	LKSqliteStatement *statement = [database statementWithQuery:query];
	
	for (TwitterStatusUpdate *status in newUpdates) {
		// Bind variables.
		[statement bindNumber:status.identifier atIndex:1];
		[statement bindDate:status.createdDate atIndex:2];
		[statement bindDate:status.receivedDate atIndex:3];
		[statement bindNumber:status.userIdentifier atIndex:4];
		[statement bindString:status.userScreenName atIndex:5];
		
		[statement bindString:status.profileImageURL atIndex:6];
		[statement bindNumber:status.inReplyToStatusIdentifier atIndex:7];
		[statement bindNumber:status.inReplyToUserIdentifier atIndex:8];
		[statement bindString:status.inReplyToScreenName atIndex:9];
		[statement bindString:status.text atIndex:10];
		
		[statement bindString:status.source atIndex:11];
		[statement bindNumber:status.retweetedStatusIdentifier atIndex:12];
		[statement bindInteger:status.locked atIndex:13];
		
		// Execute and reset.
		[statement step];
		[statement reset];
	}
}

- (TwitterStatusUpdate *)statusUpdateWithDatabaseRow:(NSDictionary *)row {
	TwitterStatusUpdate *status = [[[TwitterStatusUpdate alloc] init] autorelease];
	
	status.identifier = [row objectForKey:@"identifier"];
	status.createdDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[row objectForKey:@"createdDate"] doubleValue]];
	status.receivedDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[row objectForKey:@"receivedDate"] doubleValue]];
	status.userIdentifier = [row objectForKey:@"userIdentifier"];
	status.userScreenName = [row objectForKey:@"userScreenName"];

	status.profileImageURL = [row objectForKey:@"profileImageURL"];
	status.inReplyToStatusIdentifier = [row objectForKey:@"inReplyToStatusIdentifier"];
	status.inReplyToUserIdentifier = [row objectForKey:@"inReplyToUserIdentifier"];
	status.inReplyToScreenName = [row objectForKey:@"inReplyToScreenName"];
	status.text = [row objectForKey:@"text"];

	status.source = [row objectForKey:@"source"];
	status.retweetedStatusIdentifier = [row objectForKey:@"retweetedStatusIdentifier"];
	status.locked = [[row objectForKey:@"locked"] boolValue];
	
	return status;
}

- (TwitterStatusUpdate *)statusUpdateWithIdentifier:(NSNumber *)identifier {
	TwitterStatusUpdate *status = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"SELECT * FROM StatusUpdates WHERE identifier == ?"];
	[statement bindNumber:identifier atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		status = [self statusUpdateWithDatabaseRow:[statement rowData]];
	}
	return status;
}

- (NSSet*) statusUpdatesInReplyToStatusIdentifier:(NSNumber*)identifier {
	NSMutableSet *resultSet = [NSMutableSet set];
	TwitterStatusUpdate *status = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"SELECT * FROM StatusUpdates WHERE inReplyToStatusIdentifier == ?"];
	[statement bindNumber:identifier atIndex:1];
	while ([statement step] == SQLITE_ROW) { // Row has data.
		status = [self statusUpdateWithDatabaseRow:[statement rowData]];
		[resultSet addObject:status]; 
	}
	return resultSet;
}


#pragma mark Users

- (void)addUsers:(NSSet *)newUsers {
	if (newUsers.count == 0) return;
	
	// Insert or replace rows. Rows with the same user identifier will be replaced with the new one.
	NSString *query = @"INSERT OR REPLACE INTO Users (identifier, screenName, fullName, bio, location,   profileImageURL, webURL, friendsCount, followersCount, statusesCount,   favoritesCount, createdDate, updatedDate, locked, verified) VALUES (?, ?, ?, ?, ?,   ?, ?, ?, ?, ?,   ?, ?, ?, ?, ?)";
	LKSqliteStatement *statement = [database statementWithQuery:query];
	
	for (TwitterUser *user in newUsers) {
		// Bind variables.
		[statement bindNumber:user.identifier atIndex:1];
		[statement bindString:user.screenName atIndex:2];
		[statement bindString:user.fullName atIndex:3];
		[statement bindString:user.bio atIndex:4];
		[statement bindString:user.location atIndex:5];

		[statement bindString:user.profileImageURL atIndex:6];
		[statement bindString:user.webURL atIndex:7];
		[statement bindNumber:user.friendsCount atIndex:8];
		[statement bindNumber:user.followersCount atIndex:9];
		[statement bindNumber:user.statusesCount atIndex:10];

		[statement bindNumber:user.favoritesCount atIndex:11];
		[statement bindDate:user.createdDate atIndex:12];
		[statement bindDate:user.updatedDate atIndex:13];
		[statement bindInteger:user.locked atIndex:14];
		[statement bindInteger:user.verified atIndex:15];

		// Execute and reset.
		[statement step];
		[statement reset];
	}
}

- (TwitterUser *)userWithDatabaseRow:(NSDictionary *)row {
	TwitterUser *user = [[[TwitterUser alloc] init] autorelease];
	
	user.identifier = [row objectForKey:@"identifier"];
	user.screenName = [row objectForKey:@"screenName"];
	user.fullName = [row objectForKey:@"fullName"];
	user.bio = [row objectForKey:@"bio"];
	user.location = [row objectForKey:@"location"];
	
	user.profileImageURL = [row objectForKey:@"profileImageURL"];
	user.webURL = [row objectForKey:@"webURL"];
	user.friendsCount = [row objectForKey:@"friendsCount"];
	user.followersCount = [row objectForKey:@"followersCount"];
	user.statusesCount = [row objectForKey:@"statusesCount"];
	
	user.favoritesCount = [row objectForKey:@"favoritesCount"];
	user.createdDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[row objectForKey:@"createdDate"] doubleValue]];
	user.updatedDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[row objectForKey:@"updatedDate"] doubleValue]];
	user.locked = [[row objectForKey:@"locked"] boolValue];
	user.verified = [[row objectForKey:@"verified"] boolValue];
	
	return user;
}

- (TwitterUser *)userWithScreenName:(NSString *)screenName {
	TwitterUser *user = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"SELECT * FROM Users WHERE screenName LIKE ?"];
	[statement bindString:screenName atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		user = [self userWithDatabaseRow:[statement rowData]];
	}
	return user;
}

- (TwitterUser *)userWithIdentifier:(NSNumber *)identifier {
	TwitterUser *user = nil;
	LKSqliteStatement *statement = [database statementWithQuery:@"SELECT * FROM Users WHERE identifier == ?"];
	[statement bindNumber:identifier atIndex:1];
	if ([statement step] == SQLITE_ROW) { // Row has data.
		user = [self userWithDatabaseRow:[statement rowData]];
	}
	return user;
}

#pragma mark User defaults

- (void) saveUserDefaults {
	// Save only twitter account info
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.accounts];
	[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"allAccounts"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
