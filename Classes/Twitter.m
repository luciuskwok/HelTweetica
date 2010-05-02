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


#define kMaxNumberOfMessagesInATimeline 600
	// When reloading a timeline, newly downloaded messages are merged with existing ones, sorted by identifier, and the oldest ones past this limit are trimmed off.
#define kMaxMessageStaleness (20 * 60) 
	// When reloading a timeline, when the newest message in the app is older than this, the app reloads the entire timeline instead of requesting only status updates newer than the newest in the app. This is set to 20 minutes. The number is in seconds.


// HelTweetica twitter consumer/client credentials.
// Please use your own application credentials, which you can request from Twitter.

// You will need to supply your own credentials in the file imported here:
#import "(HelTweeticaConsumerToken).h"
// The file shoud contain the following two lines:
// #define kConsumerKey @"xxxxxxxxxxxxxxxx"
// #define kConsumerSecret @"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"



@interface Twitter (PrivateMethods)
- (TwitterAccount*) accountWithScreenName: (NSString*) screenName;

- (TwitterMessage*) statusWithIdentifier:(NSNumber*)identifier;
- (NSArray*) mergeNewMessages:(NSArray*) newMessages withOldMessages:(NSArray*) oldMessages;
- (TwitterMessage*) messageWithIdentifier: (NSNumber*) identifier existsInArray: (NSArray*) array;
- (void)synchronizeStatusesWithArray:(NSMutableArray *)newStatuses updateFavorites:(BOOL)updateFaves;
@end

@implementation Twitter
@synthesize accounts, currentAccount, currentTimeline, currentTimelineAction, delegate;


- (id) init {
	if (self = [super init]) {
		statuses = [[NSMutableSet alloc] init];
		actions = [[NSMutableArray alloc] init];
		defaultCount = [@"100" retain];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSData *accountsData = [defaults objectForKey: @"twitterAccounts"];
		
		if (accountsData != nil) {
			self.accounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
			
			// Add all statuses to set
			for (TwitterAccount *account in accounts) {
				[self synchronizeStatusesWithArray: account.timeline updateFavorites:YES]; // TODO: Unique each array element
				[self synchronizeStatusesWithArray: account.mentions updateFavorites:YES];
				[self synchronizeStatusesWithArray: account.favorites updateFavorites:YES];
			}
			
			NSString *currentAccountScreenName = [defaults objectForKey: @"currentAccount"];
			if (currentAccountScreenName) {
				self.currentAccount = [self accountWithScreenName:currentAccountScreenName];
			} else {
				if (self.accounts.count > 0) 
					self.currentAccount = [self.accounts objectAtIndex: 0];
			}
		}
	}
	return self;
}

- (void) dealloc {
	[accounts release];
	[currentAccount release];
	[currentTimeline release];
	[statuses release];
	[actions release];
	[defaultCount release];
	
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
#pragma mark TwitterAction

- (void) startTwitterAction:(TwitterAction*)action withToken:(BOOL)useToken {
	// Add the action to the array of actions, and updates the network activity spinner
	[actions addObject: action];

	// Set up Twitter action
	action.delegate = self;
	if (useToken) {
		action.consumerToken = currentAccount.xAuthToken;
		action.consumerSecret = currentAccount.xAuthSecret;
	}
	
	// Start the URL connection
	[action start];
}

- (void) removeTwitterAction:(TwitterAction*)action {
	// Removes the action from the array of actions, and updates the network activity spinner
	[actions removeObject: action];
}

- (void) loginScreenName:(NSString*)aScreenName password:(NSString*)aPassword {
	// Create an account for this username if one doesn't already exist
	TwitterAccount *account = [self accountWithScreenName: aScreenName];
	if (account == nil) {
		account = [[[TwitterAccount alloc] init] autorelease];
		account.screenName = aScreenName;
		[accounts addObject: account];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"twitterAccountsDidChange" object:self];
	}

	// Create and send the login action.
	TwitterLoginAction *action = [[[TwitterLoginAction alloc] initWithUsername:aScreenName password:aPassword] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLogin:);
	[self startTwitterAction:action withToken:NO];
}

- (void) didLogin:(TwitterLoginAction *)action {
	if (action.token) {
		// Save the login information for the account.
		TwitterAccount *account = [self accountWithScreenName: action.username];
		[account setXAuthToken: action.token];
		[account setXAuthSecret: action.secret];
		[account setScreenName: action.username]; // To make sure the uppercase/lowercase letters are correct.
		[self setCurrentAccount: account];
		[self saveAccounts];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"currentAccountDidChange" object:self];
	} else {
		// Login was not successful, so report the error.
		if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
			NSError *error = [NSError errorWithDomain:@"Network" code:action.statusCode userInfo:nil];
			[delegate twitter:self didFailWithNetworkError:error];
		}
	}
}

- (void) updateStatus:(NSString*)text inReplyTo:(NSNumber*)messageIdentifier {
	TwitterUpdateStatusAction *action = [[[TwitterUpdateStatusAction alloc] initWithText:text inReplyTo:messageIdentifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didUpdateStatus:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didUpdateStatus:(TwitterUpdateStatusAction *)action {
	if ((action.statusCode < 400) || (action.statusCode == 403)) { // Twitter returns 403 if user tries to post duplicate status updates.
		// Remove message text from compose screen.
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:@"" forKey:@"messageContent"];
		[defaults removeObjectForKey:@"inReplyTo"];
		
		// Reload timeline
		[self reloadCurrentTimeline];
	} else {
		// Report error to delegate
		if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
			NSError *error = [NSError errorWithDomain:@"Network" code:action.statusCode userInfo:nil];
			[delegate twitter:self didFailWithNetworkError:error];
		}
	}
}

- (void) fave: (NSNumber*) messageIdentifier {
	TwitterMessage *message = [self statusWithIdentifier: messageIdentifier];
	if (message == nil) {
		NSLog (@"Cannot find the message to fave (or unfave). id == %@", messageIdentifier);
		return;
	}
	
	TwitterFavoriteAction *action = [[[TwitterFavoriteAction alloc] initWithMessage:message destroy:message.favorite] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didFave:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didFave:(TwitterFavoriteAction *)action {
	TwitterMessage *message = [action message];
	
	// Change the display of the star next to tweet in root view
	if ([delegate respondsToSelector:@selector(twitter:favoriteDidChange:)])
		[delegate twitter:self favoriteDidChange:message];
}

- (void)retweet:(NSNumber*)messageIdentifier {
	TwitterRetweetAction *action = [[[TwitterRetweetAction alloc] initWithMessageIdentifier:messageIdentifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didRetweet:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didRetweet:(TwitterRetweetAction *)action {
	// Change the display of the star next to tweet in root view
	if ([delegate respondsToSelector:@selector(twitterDidRetweet:)])
		[delegate twitterDidRetweet:self];
}

#pragma mark -
#pragma mark TwitterActions - Timeline

// TODO: add own RTs to home timeline
// See http://apiwiki.twitter.com/Twitter-REST-API-Method%3A-statuses-retweeted_by_me

- (void)reloadCurrentTimeline {
	// Set the since_id parameter if there already are messages in the current timeline
	NSNumber *newerThan = nil;
	if ([currentTimeline count] > 10) {
		TwitterMessage *message = [currentTimeline objectAtIndex: 0];
		NSTimeInterval staleness = -[message.receivedDate timeIntervalSinceNow];
		if (staleness < kMaxMessageStaleness) {
			newerThan = message.identifier;
		}
	}
	
	TwitterAction *action = self.currentTimelineAction;
	if (newerThan)
		[action.parameters setObject:[newerThan stringValue] forKey:@"since_id"];
	
	// Prepare action and start it. 
	action.completionTarget= self;
	action.completionAction = @selector(didReloadCurrentTimeline:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didReloadCurrentTimeline:(TwitterLoadTimelineAction *)action {
	if (action.messages.count > 0) {
		NSMutableArray *newMessages = [NSMutableArray arrayWithArray: action.messages];
	
		// Search results will not have valid favorite flag data because it's not linked to an account.
		BOOL updateFaves = ([action isKindOfClass:[TwitterSearchAction class]] == NO); 
		[self synchronizeStatusesWithArray: newMessages updateFavorites:updateFaves];
		
		// Merge downloaded messages with existing messages.
		for (TwitterMessage *message in newMessages) {
			if ([currentTimeline containsObject:message] == NO)
				[currentTimeline addObject: message];
		}
		
		// Sort by identifier, descending.
		NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
		[currentTimeline sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
		
		// Keep timeline within size limits by removing old messages.
		if (currentTimeline.count > kMaxNumberOfMessagesInATimeline) {
			NSRange removalRange = NSMakeRange(kMaxNumberOfMessagesInATimeline, currentTimeline.count - kMaxNumberOfMessagesInATimeline);
			[currentTimeline removeObjectsInRange:removalRange];
		}
	}
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didFinishLoadingTimeline:)])
		[delegate twitter:self didFinishLoadingTimeline:currentTimeline];
}


- (void)selectHomeTimeline {
	if (currentAccount.timeline == nil) 
		currentAccount.timeline = [NSMutableArray array];
	self.currentTimeline = currentAccount.timeline;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/home_timeline"] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"count"];
}

- (void)selectMentions {
	if (currentAccount.mentions == nil) 
		currentAccount.mentions = [NSMutableArray array];
	self.currentTimeline = currentAccount.mentions;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/mentions"] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"count"];
}

- (void)selectDirectMessages {
	if (currentAccount.directMessages == nil) 
		currentAccount.directMessages = [NSMutableArray array];
	self.currentTimeline = currentAccount.directMessages;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"direct_messages"] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"count"];
}

- (void)selectFavorites {
	if (currentAccount.favorites == nil) 
		currentAccount.favorites = [NSMutableArray array];
	self.currentTimeline = currentAccount.favorites;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	// Favorites always loads 20 per page. Cannot change the count.
}

- (void) selectTimelineOfList:(TwitterList*)list {
	if (list.statuses == nil)
		list.statuses = [NSMutableArray array];
	self.currentTimeline = list.statuses;

	NSString *method = [NSString stringWithFormat:@"%@/lists/%@/statuses", list.username, list.identifier];
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:method] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"per_page"];
}

- (void) selectSearchTimelineWithQuery:(NSString*)query {
	self.currentTimeline = [NSMutableArray array]; // Always start with an empty array of messages for Search.
	
	TwitterSearchAction *action = [[[TwitterSearchAction alloc] initWithQuery:query count:defaultCount] autorelease];
	self.currentTimelineAction = action;
}

- (BOOL) isLoading {
	return actions.count > 0;
}

#pragma mark -
#pragma mark TwitterAction delegate methods

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	[self removeTwitterAction:action];
	
	// Deal with status codes 400 to 402 and 404 and up.
	if ((action.statusCode >= 400) && (action.statusCode != 403)) {
		if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
			NSError *error = [NSError errorWithDomain:@"Network" code:action.statusCode userInfo:nil];
			[delegate twitter:self didFailWithNetworkError:error];
		}
	}
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
		[delegate twitter:self didFailWithNetworkError:error];
	}
	[actions removeObject: action];
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

- (TwitterMessage*) statusWithIdentifier:(NSNumber*)identifier {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
	//NSLog (@"predicate: %@", predicate);
	NSSet *filteredSet = [statuses filteredSetUsingPredicate:predicate];
	if (filteredSet.count > 1) {
		NSLog (@"More than one status update found matching predicate.");
	}
	return [filteredSet anyObject];
}

- (NSArray*) mergeNewMessages:(NSArray*) newMessages withOldMessages:(NSArray*) oldMessages {
	// If there are no messages in one of the arrays, just return the other.
	if ([oldMessages count] == 0) return newMessages;
	if ([newMessages count] == 0) return oldMessages;
	
	NSMutableArray *result = [NSMutableArray arrayWithArray: newMessages];
	for (TwitterMessage *message in oldMessages) {
		if ([self messageWithIdentifier:message.identifier existsInArray:newMessages] == NO) {	
			[result addObject: message];
		}
	}
	
	return result;
}

- (TwitterMessage*) messageWithIdentifier: (NSNumber*) identifier existsInArray: (NSArray*) array {
	TwitterMessage *message;
	for (message in array) {
		if ([identifier isEqualToNumber: message.identifier])
			return message;
	}
	return nil;
}

#pragma mark -

- (void) saveAccounts {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [NSKeyedArchiver archivedDataWithRootObject:accounts] forKey: @"twitterAccounts"];
	[defaults setObject: self.currentAccount.screenName forKey: @"currentAccount"];
}

@end
