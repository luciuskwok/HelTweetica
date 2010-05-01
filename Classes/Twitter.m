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
- (void)synchronizeStatusesWithArray:(NSMutableArray *)newStatuses;
@end

@implementation Twitter
@synthesize accounts, currentAccount, delegate;


- (id) init {
	if (self = [super init]) {
		statuses = [[NSMutableSet alloc] init];
		actions = [[NSMutableArray alloc] init];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSData *accountsData = [defaults objectForKey: @"twitterAccounts"];
		
		if (accountsData != nil) {
			self.accounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
			
			// Add all statuses to set
			for (TwitterAccount *account in accounts) {
				[statuses addObjectsFromArray: account.timeline]; // TODO: Unique each array element
				[statuses addObjectsFromArray: account.mentions];
				[statuses addObjectsFromArray: account.favorites];
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
	[statuses release];
	[actions release];
	
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

- (void)reloadHomeTimeline {
	NSNumber *newerThan = nil;
	if ([currentAccount.timeline count] > 3) {
		TwitterMessage *message = [currentAccount.timeline objectAtIndex: 0];
		NSTimeInterval staleness = -[message.receivedDate timeIntervalSinceNow];
		if (staleness < kMaxMessageStaleness) {
			newerThan = message.identifier;
		}
	}

	NSNumber *count = [NSNumber numberWithInt:200];
	TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/home_timeline" sinceIdentifier:newerThan maxIdentifier:nil count:count page:nil] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didReloadHomeTimeline:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didReloadHomeTimeline:(TwitterLoadTimelineAction *)action {
	if (action.messages.count > 0) {
		NSMutableArray *newMessages = [NSMutableArray arrayWithArray: action.messages];
		[self synchronizeStatusesWithArray: newMessages];
		
		if (newMessages.count < 120) { // Merge when only a few messages came in
			currentAccount.timeline = [self mergeNewMessages:newMessages withOldMessages:currentAccount.timeline];
		} else { // Show only new messaages and discard old ones when we get a lot
			currentAccount.timeline = newMessages;
		}
	}
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didFinishLoadingTimeline:)])
		[delegate twitter:self didFinishLoadingTimeline:currentAccount.timeline];
}

- (void) reloadMentions {
	NSNumber *newerThan = nil;
	if ([currentAccount.mentions count] > 3) {
		TwitterMessage *message = [currentAccount.mentions objectAtIndex: 0];
		NSTimeInterval staleness = -[message.receivedDate timeIntervalSinceNow];
		if (staleness < kMaxMessageStaleness) {
			newerThan = message.identifier;
		}
	}
	
	NSNumber *count = [NSNumber numberWithInt:200];
	TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/mentions" sinceIdentifier:newerThan maxIdentifier:nil count:count page:nil] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didReloadMentions:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didReloadMentions:(TwitterLoadTimelineAction *)action {
	if (action.messages.count > 0) {
		NSMutableArray *newMessages = [NSMutableArray arrayWithArray: action.messages];
		[self synchronizeStatusesWithArray: newMessages];
		
		if (newMessages.count < 120) { // Merge when only a few messages came in
			currentAccount.mentions = [self mergeNewMessages:newMessages withOldMessages:currentAccount.mentions];
		} else { // Show only new messaages and discard old ones when we get a lot
			currentAccount.mentions = newMessages;
		}
	}
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didFinishLoadingTimeline:)])
		[delegate twitter:self didFinishLoadingTimeline:currentAccount.mentions];
}

- (void) reloadDirectMessages {
	NSNumber *newerThan = nil;
	if ([currentAccount.directMessages count] > 3) {
		TwitterMessage *message = [currentAccount.directMessages objectAtIndex: 0];
		NSTimeInterval staleness = -[message.receivedDate timeIntervalSinceNow];
		if (staleness < kMaxMessageStaleness) {
			newerThan = message.identifier;
		}
	}
	
	NSNumber *count = [NSNumber numberWithInt:200];
	TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"direct_messages" sinceIdentifier:newerThan maxIdentifier:nil count:count page:nil] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didReloadDirectMessages:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didReloadDirectMessages:(TwitterLoadTimelineAction *)action {
	if (action.messages.count > 0) {
		// Do not include direct messages in the statuses set because their message IDs can conflict with those of public status updates.
		
		if (action.messages.count < 120) { // Merge when only a few messages came in
			currentAccount.directMessages = [self mergeNewMessages:action.messages withOldMessages:currentAccount.directMessages];
		} else { // Show only new messaages and discard old ones when we get a lot
			currentAccount.directMessages = action.messages;
		}
	}
	
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didFinishLoadingTimeline:)])
		[delegate twitter:self didFinishLoadingTimeline:currentAccount.directMessages];
}

- (void) reloadFavorites {
	TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites" sinceIdentifier:nil maxIdentifier:nil count:nil page:nil] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didReloadFavorites:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didReloadFavorites:(TwitterLoadTimelineAction *)action {
	if (action.messages.count > 0) {
		NSMutableArray *newMessages = [NSMutableArray arrayWithArray: action.messages];
		[self synchronizeStatusesWithArray: newMessages];
		
		currentAccount.favorites = [self mergeNewMessages:newMessages withOldMessages:currentAccount.favorites];
	}
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didFinishLoadingTimeline:)])
		[delegate twitter:self didFinishLoadingTimeline:currentAccount.favorites];
}

#pragma mark -
#pragma mark TwitterAction - Lists

- (void) loadListsOfUser:(NSString*)userOrNil {
	TwitterLoadListsAction *action = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:NO] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLoadLists:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didLoadLists:(TwitterLoadListsAction *)action {
	currentAccount.lists = action.lists;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"listsDidChange" object:self];
}

- (void) loadListSubscriptionsOfUser:(NSString*)userOrNil {
	TwitterLoadListsAction *action = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:YES] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLoadListSubscriptions:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didLoadListSubscriptions:(TwitterLoadListsAction *)action {
	currentAccount.listSubscriptions = action.lists;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"listSubscriptionsDidChange" object:self];
}

- (void) loadTimelineOfList:(TwitterList*)list {
	NSNumber *count = [NSNumber numberWithInt:200];
	NSString *method = [NSString stringWithFormat:@"%@/lists/%@/statuses", list.username, list.identifier];
	TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:method sinceIdentifier:nil maxIdentifier:nil perPage:count page:nil] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLoadTimelineOfList:);
	action.timelineName = list.fullName;
	[self startTwitterAction:action withToken:YES];
}

- (void) didLoadTimelineOfList:(TwitterLoadTimelineAction *)action {
	NSMutableArray *newMessages = [NSMutableArray arrayWithArray: action.messages];
	[self synchronizeStatusesWithArray: newMessages];
	
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didSelectTimeline:withName:tabName:)])
		[delegate twitter:self didSelectTimeline:newMessages withName:action.timelineName tabName:@"List"];
}

#pragma mark -
#pragma mark TwitterAction - Search

- (void)loadSavedSearches {
	TwitterLoadSavedSearchesAction *action = [[[TwitterLoadSavedSearchesAction alloc] init] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLoadSavedSearches:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didLoadSavedSearches:(TwitterLoadSavedSearchesAction *)action {
	currentAccount.savedSearches = action.queries;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"savedSearchesDidChange" object:self];
}

- (void)searchWithQuery:(NSString*)query {
	TwitterSearchAction *action = [[[TwitterSearchAction alloc] initWithQuery:query] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didSearch:);
	[self startTwitterAction:action withToken:YES];
}

- (NSString *)htmlSafeString:(NSString *)string {
	NSMutableString *result = [NSMutableString stringWithString:string];
	[result replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (void) didSearch:(TwitterSearchAction *)action {
	NSMutableArray *newMessages = [NSMutableArray arrayWithArray: action.messages];
	[self synchronizeStatusesWithArray: newMessages];
	
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didSelectTimeline:withName:tabName:)]) {
		NSString *pageName = [NSString stringWithFormat: @"Search for &ldquo;%@&rdquo;", [self htmlSafeString:action.query]];
		[delegate twitter:self didSelectTimeline:newMessages withName:pageName tabName:@"Results"];
	}
}


#pragma mark -
#pragma mark TwitterAction delegate methods

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	[self removeTwitterAction:action];
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
		if (action.statusCode != 0) {
			error = [NSError errorWithDomain:@"Network" code:action.statusCode userInfo:nil];
		}
		[delegate twitter:self didFailWithNetworkError:error];
	}
	[actions removeObject: action];
}

#pragma mark -

- (void)synchronizeStatusesWithArray:(NSMutableArray *)newStatuses {
	// For matching statuses already in the set, replace the ones in the array with those from the set, so that messages that are equal always have only one representation in memory. 
	TwitterMessage *existingMessage, *newMessage;
	int index;
	for (index = 0; index < newStatuses.count; index++) {
		newMessage = [newStatuses objectAtIndex: index];
		existingMessage = [statuses member:newMessage];
		if (existingMessage) {
			// Message already exists, but still need to update the favorite status and timestamp of the message.
			existingMessage.favorite = newMessage.favorite;
			existingMessage.receivedDate = newMessage.receivedDate;
			[newStatuses replaceObjectAtIndex:index withObject:existingMessage];
		} else {
			// Add the message to the set.
			[statuses addObject:newMessage];
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
