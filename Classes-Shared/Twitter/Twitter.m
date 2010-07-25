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

#import "TwitterFavoriteAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"



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
		[self load];
	}
	return self;
}

- (void) dealloc {
	[accounts release];
	[statuses release];
	[super dealloc];
}

#pragma mark -

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


#pragma mark -

- (void)synchronizeStatusesWithArray:(NSMutableArray *)newStatuses {
	// For matching statuses already in the set, replace the ones in the array with those from the set, so that messages that are equal always have only one representation in memory. 
	TwitterMessage *existingMessage, *newMessage;
	int index;
	for (index = 0; index < newStatuses.count; index++) {
		newMessage = [newStatuses objectAtIndex: index];
		if (newMessage.direct == NO) { // Only sync with public status updates, not direct messages.
			existingMessage = [statuses member:newMessage];
			if (existingMessage) {
				// Update received date.
				existingMessage.receivedDate = newMessage.receivedDate;
				[newStatuses replaceObjectAtIndex:index withObject:existingMessage];
			} else {
				// Add the message to the set.
				[statuses addObject:newMessage];
			}
		}
	}
}

- (void)addUsers:(NSSet *)newUsers {
	// Update set of users.
	TwitterUser *member;
	for (TwitterUser *user in newUsers) {
		member = [self.users member:user];
		if (member && [user isNewerThan:member]) {
			// Copy data from old user to new user instance
			user.statuses = member.statuses;
			user.favorites = member.favorites;
			user.lists = member.lists;
			user.listSubscriptions = member.listSubscriptions;
			
			// Remove old user
			[self.users removeObject:member];
		}
		
		// Add new user. If user already is in self.users, this does nothing.
		[self.users addObject: user];
	}
}

#pragma mark -

- (TwitterMessage*) statusWithIdentifier:(NSNumber*)identifier {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
	NSSet *filteredSet = [statuses filteredSetUsingPredicate:predicate];
	TwitterMessage *message = [filteredSet anyObject];
	
	// Check for retweets
	if (filteredSet.count == 0) {
		predicate = [NSPredicate predicateWithFormat:@"retweetedMessage.identifier == %@", identifier];
		filteredSet = [statuses filteredSetUsingPredicate:predicate];
		message = [filteredSet anyObject];
		return message.retweetedMessage;
	}
	
	return message;
}

- (NSSet*) statusesInReplyToStatusIdentifier:(NSNumber*)identifier {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"inReplyToStatusIdentifier == %@", identifier];
	return [statuses filteredSetUsingPredicate:predicate];
}

- (TwitterUser *)userWithScreenName:(NSString *)screenName {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"screenName LIKE[cd] %@", screenName];
	NSSet *filteredSet = [users filteredSetUsingPredicate:predicate];
	return [filteredSet anyObject];
}

#pragma mark Load and Save cache to disk

/*	User data is stored in two places. The list of accounts is stored in user defaults. The status updates and user profiles are stored in the Cache folder.
 */

- (NSString *)twitterCacheFilePath {
	// Create a new sqlite database if none exists.
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cachePath = [paths objectAtIndex:0];
	return [cachePath stringByAppendingPathComponent:@"TwitterCache.db"];
}

- (BOOL)createTwitterCacheAtPath:(NSString *)path {
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		// Copy the existing database template from the App bundle
		NSString *templateFile = [[NSBundle mainBundle] pathForResource:@"TwitterCacheTemplate" ofType:@"db"];
		NSError *error = nil;
		if ([[NSFileManager defaultManager] copyItemAtPath:templateFile toPath:path error:&error] == NO) {
			NSLog (@"Error while creating new Twitter cache: %@", [error localizedDescription]);
			return NO;
		}
	}
	return YES;
}

- (void) load {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Remove old preferences if they exist, to free up disk space.
	[defaults removeObjectForKey:@"twitterAccounts"];
	[defaults removeObjectForKey:@"twitterUsers"];
	
	// Load account info from user defaults
	NSData *data = [defaults objectForKey:@"allAccounts"];
	if (data != nil)
		self.accounts = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	// Create a new sqlite database if none exists.
	NSString *cacheFile = [self twitterCacheFilePath];
	if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFile] == NO) {
		BOOL success = [self createTwitterCacheAtPath:cacheFile];
		if (!success) return;
	}
	
	int error;
	error = sqlite3_open ([cacheFile cStringUsingEncoding:NSUTF8StringEncoding], &database);
	if (error != 0) {
		NSLog (@"Error result from sqlite3_open(): %d", error);
		sqlite3_close (database);
	}
}

- (void) save {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Save only twitter account info
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.accounts];
	[defaults setObject:data forKey:@"allAccounts"];
	
	// TODO: change architecture to avoid needing to save entire database. 

	// Synchronize sqlite db in preparation for quitting.
	int error;
	error = sqlite3_close (database);
	if (error != 0) NSLog (@"Error result from sqlite3_close(): %d", error);
}

@end
