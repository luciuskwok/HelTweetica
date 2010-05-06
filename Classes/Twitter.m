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



#import "TwitterFavoriteAction.h"
#import "TwitterLoginAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"
#import "TwitterSearchAction.h"




// HelTweetica twitter consumer/client credentials.
// Please use your own application credentials, which you can request from Twitter.

// You will need to supply your own credentials in the file imported here:
#import "(HelTweeticaConsumerToken).h"
// The file shoud contain the following two lines:
// #define kConsumerKey @"xxxxxxxxxxxxxxxx"
// #define kConsumerSecret @"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"


@implementation Twitter
@synthesize accounts, users, statuses;


- (id) init {
	if (self = [super init]) {
		statuses = [[NSMutableSet alloc] init];
		[self load];
	}
	return self;
}

- (void) dealloc {
	[accounts release];
	[users release];
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

- (void)synchronizeStatusesWithArray:(NSMutableArray *)newStatuses updateFavorites:(BOOL)updateFaves {
	// For matching statuses already in the set, replace the ones in the array with those from the set, so that messages that are equal always have only one representation in memory. 
	TwitterMessage *existingMessage, *newMessage;
	int index;
	for (index = 0; index < newStatuses.count; index++) {
		newMessage = [newStatuses objectAtIndex: index];
		if (newMessage.direct == NO) { // Only sync with public status updates, not direct messages.
			existingMessage = [statuses member:newMessage];
			if (existingMessage) {
				// Message already exists, but still need to update the favorite status and timestamp of the message.
				if (updateFaves)
					existingMessage.favorite = newMessage.favorite;
				existingMessage.inReplyToScreenName = newMessage.inReplyToScreenName;
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
		if (member) {
			// Copy data from old user to new user instance
			user.statuses = member.statuses;
			user.favorites = member.favorites;
			user.lists = member.lists;
			user.listSubscriptions = member.listSubscriptions;
			
			// Remove old user
			[self.users removeObject:member];
		}
		
		// Add new user
		[self.users addObject: user];
	}
}

#pragma mark -

- (TwitterMessage*) statusWithIdentifier:(NSNumber*)identifier {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
	NSSet *filteredSet = [statuses filteredSetUsingPredicate:predicate];
	return [filteredSet anyObject];
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

- (void) load {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Twitter Accounts
	NSData *accountsData = [defaults objectForKey: @"twitterAccounts"];
	if (accountsData != nil) {
		self.accounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
		
		// Add all statuses to set
		for (TwitterAccount *account in accounts) {
			[self synchronizeStatusesWithArray: account.timeline updateFavorites:YES];
			[self synchronizeStatusesWithArray: account.mentions updateFavorites:YES];
			[self synchronizeStatusesWithArray: account.favorites updateFavorites:YES];
		}
		
	}
	
	// Twitter Users
	NSData *usersData = [defaults objectForKey: @"twitterUsers"];
	if (usersData != nil) {
		self.users = [NSKeyedUnarchiver unarchiveObjectWithData:usersData];
		for (TwitterUser* user in users) {
			[self synchronizeStatusesWithArray:user.statuses updateFavorites:YES];
			[self synchronizeStatusesWithArray:user.favorites updateFavorites:YES];
		}
	} else {
		self.users = [NSMutableSet set];
	}
}

- (void) save {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [NSKeyedArchiver archivedDataWithRootObject:accounts] forKey: @"twitterAccounts"];
	[defaults setObject: [NSKeyedArchiver archivedDataWithRootObject:users] forKey: @"twitterUsers"];
}

@end
