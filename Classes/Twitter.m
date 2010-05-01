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
#import "TwitterMessageJSONParser.h"
#import "TwitterListsJSONParser.h"
#import "TwitterSavedSearchJSONParser.h"
#import "OAuthClient.h"

#import "TwitterFavoriteAction.h"
#import "TwitterLoginAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterLoadTimelineAction.h"


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

- (void) postRequestWithURL: (NSURL*) aURL body: (NSString*) aBody;
- (void) loadTimeline: (NSString*) aTimeline withCount: (int) aCount olderThan:(NSNumber*) max_id newerThan:(NSNumber*) since_id;
- (void) callMethod: (NSString*) method withParameters: (NSDictionary*) parameters;

- (TwitterMessage*) statusWithIdentifier:(NSNumber*)identifier;
- (NSArray*) mergeNewMessages:(NSArray*) newMessages withOldMessages:(NSArray*) oldMessages;
- (TwitterMessage*) messageWithIdentifier: (NSNumber*) identifier existsInArray: (NSArray*) array;

- (NSString*) URLEncodeString: (NSString*) aString;
- (NSURL*) URLWithBase: (NSString*) baseString query: (NSDictionary*) parameters;
@end

@implementation Twitter
@synthesize accounts, currentAccount, statuses, downloadConnection, downloadData, isLoading, delegate;


- (id) init {
	if (self = [super init]) {
		self.statuses = [NSSet set];
		actions = [[NSMutableArray alloc] init];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSData *accountsData = [defaults objectForKey: @"twitterAccounts"];
		
		if (accountsData != nil) {
			self.accounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
			
			// Add all status to set
			for (TwitterAccount *account in accounts) {
				self.statuses = [account setByAddingAllStatusesToSet: statuses];
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
	
	[downloadConnection release];
	[downloadData release];
	
	[super dealloc];
}

#pragma mark -

- (TwitterAccount*) accountWithScreenName: (NSString*) screenName {
	for (TwitterAccount *account in accounts) {
		if ([account.screenName isEqualToString: screenName])
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
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

	// Set up Twitter action
	action.delegate = self;
	if (useToken) {
		action.consumerToken = currentAccount.xAuthToken;
		action.consumerSecret= currentAccount.xAuthSecret;
	}
	
	// Start the URL connection
	[action start];
}

- (void) removeTwitterAction:(TwitterAction*)action {
	// Removes the action from the array of actions, and updates the network activity spinner
	[actions removeObject: action];
	if (actions.count == 0)
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
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
		// Add messages to statuses set
		self.statuses = [statuses setByAddingObjectsFromArray: action.messages];
		
		if (action.messages.count < 120) { // Merge when only a few messages came in
			currentAccount.timeline = [self mergeNewMessages:action.messages withOldMessages:currentAccount.timeline];
		} else { // Show only new messaages and discard old ones when we get a lot
			currentAccount.timeline = action.messages;
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
		// Add messages to statuses set
		self.statuses = [statuses setByAddingObjectsFromArray: action.messages];
		
		if (action.messages.count < 120) { // Merge when only a few messages came in
			currentAccount.mentions = [self mergeNewMessages:action.messages withOldMessages:currentAccount.mentions];
		} else { // Show only new messaages and discard old ones when we get a lot
			currentAccount.mentions = action.messages;
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
		// Add messages to statuses set
		self.statuses = [statuses setByAddingObjectsFromArray: action.messages];
		
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

#pragma mark -
#pragma mark TwitterAction delegate methods

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	[self removeTwitterAction:action];
}

- (void) twitterConnection:(TwitterAction*)action didFailWithError:(NSError*)error {
	if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
		NSError *error = [NSError errorWithDomain:@"Network" code:action.statusCode userInfo:nil];
		[delegate twitter:self didFailWithNetworkError:error];
	}
	[actions removeObject: action];
}

#pragma mark -

- (void) postRequestWithURL: (NSURL*) aURL body: (NSString*) aBody {
	[self cancel]; // Cancel any pending requests.
	
	if ((currentAccount.xAuthToken == nil) || (currentAccount.xAuthSecret == nil)) {
		//[statusLabel setText:@"Not logged in."];
		NSLog (@"Not logged in.");
		return;
	}
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:aURL];
	[request setHTTPMethod:@"POST"];
	if (aBody != nil)
		[request setHTTPBody: [aBody dataUsingEncoding:NSUTF8StringEncoding]];
	
	// OAuth Authorization
	OAuthClient *oauth = [[OAuthClient alloc] initWithClientKey:kConsumerKey clientSecret:kConsumerSecret];
	[oauth setUserKey:currentAccount.xAuthToken userSecret: currentAccount.xAuthSecret];
	NSString *authorization = [oauth authorizationHeaderWithURLRequest: request];
	[request setValue: authorization forHTTPHeaderField:@"Authorization"];
	
	// Create the download connection
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	downloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES];
	isLoading = YES;

	// Clean up
	[request release];
	[oauth release];
}


#pragma mark -

- (void) loadFavoritesWithUser:(NSString*)userOrNil page:(int)page {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	if (page > 0) [parameters setObject:[NSString stringWithFormat:@"%d", page] forKey:@"page"];
	if (userOrNil != nil) [parameters setObject:userOrNil forKey:@"id"];
	
	downloadCompleteAction = @selector(favoritesReceived:);
	[self callMethod:@"favorites" withParameters: parameters];
}

- (void) loadListsWithUser:(NSString*)user {
	downloadCompleteAction = @selector(listsReceived:);
	NSString *method = (user != nil) ? [NSString stringWithFormat:@"%@/lists", user] : @"lists";
	[self callMethod:method withParameters: nil];
}

- (void) loadListSubscriptionsWithUser:(NSString*)user {
	downloadCompleteAction = @selector(listSubscriptionsReceived:);
	NSString *method = (user != nil) ? [NSString stringWithFormat:@"%@/lists/subscriptions", user] : @"lists/subscriptions";
	[self callMethod:method withParameters: nil];
}

- (void)loadSavedSearches {
	downloadCompleteAction = @selector(savedSearchesReceived:);
	[self callMethod:@"saved_searches" withParameters: nil];
}

- (void) loadTimeline: (NSString*) timeline withCount: (int) aCount olderThan:(NSNumber*) aMaxID newerThan:(NSNumber*) aSinceID {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	if (aCount > 0) [parameters setObject:[NSString stringWithFormat:@"%d", aCount] forKey:@"count"];
	if (aMaxID != nil) [parameters setObject:[aMaxID stringValue] forKey:@"max_id"];
	if (aSinceID != nil) [parameters setObject:[aSinceID stringValue] forKey:@"since_id"];
	
	[self callMethod:timeline withParameters:parameters];
}

- (void) callMethod: (NSString*) method withParameters: (NSDictionary*) parameters {
	// Cancel any pending requests.
	[self cancel];
	
	if (([currentAccount xAuthToken] == nil) || ([currentAccount xAuthSecret] == nil)) {
		//[statusLabel setText:@"Not logged in."];
		NSLog (@"Not logged in.");
		return;
	}
	
	NSString *base = [NSString stringWithFormat:@"http://api.twitter.com/1/%@.json", method]; // version 1 only
	NSURL *url = [self URLWithBase:base query:parameters];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	[request setHTTPMethod:@"GET"];
	
	// OAuth Authorization
	OAuthClient *oauth = [[OAuthClient alloc] initWithClientKey:kConsumerKey clientSecret:kConsumerSecret];
	[oauth setUserKey:currentAccount.xAuthToken userSecret: currentAccount.xAuthSecret];
	NSString *authorization = [oauth authorizationHeaderWithURLRequest: request];
	[request setValue: authorization forHTTPHeaderField:@"Authorization"];
	
	// Create the download connection
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	self.downloadConnection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES] autorelease];
	isLoading = YES;
	
	// Clean up
	[request release];
	[oauth release];
}

- (void)favoritesReceived:(NSData*)receivedData {
	TwitterMessageJSONParser *parser = [[TwitterMessageJSONParser alloc] init];
	parser.receivedTimestamp = [NSDate date];
	NSArray *newMessages = [parser messagesWithJSONData:receivedData];
	[parser release];
	
	if ([newMessages count] > 0) {
		// Add messages to statuses set
		self.statuses = [statuses setByAddingObjectsFromArray: newMessages];
		currentAccount.favorites = [self mergeNewMessages:newMessages withOldMessages:currentAccount.favorites];
	}
	// Call delegate to tell it we're finished loading
	if ([delegate respondsToSelector:@selector(twitter:didFinishLoadingTimeline:)])
		[delegate twitter:self didFinishLoadingTimeline:currentAccount.favorites];
}

- (void)listsReceived:(NSData*)receivedData {
	TwitterListsJSONParser *parser = [[TwitterListsJSONParser alloc] init];
	currentAccount.lists = [parser listsWithJSONData:receivedData];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"listsDidChange" object:self];
	[parser release];
}

- (void)listSubscriptionsReceived:(NSData*)receivedData {
	TwitterListsJSONParser *parser = [[TwitterListsJSONParser alloc] init];
	currentAccount.listSubscriptions = [parser listsWithJSONData:receivedData];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"listSubscriptionsDidChange" object:self];
	[parser release];
}

- (void)savedSearchesReceived:(NSData*)receivedData {
	TwitterSavedSearchJSONParser *parser = [[TwitterSavedSearchJSONParser alloc] init];
	currentAccount.savedSearches = [parser queriesWithJSONData:receivedData];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"savedSearchesDidChange" object:self];
	[parser release];
}

- (void) cancel {
	[self.downloadConnection cancel];
	isLoading = NO;
}

#pragma mark -

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
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
		downloadStatusCode = [(NSHTTPURLResponse*) response statusCode];
		if (downloadStatusCode >= 400) {
			if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
				NSError *error = [NSError errorWithDomain:@"Network" code:downloadStatusCode userInfo:nil];
				[delegate twitter:self didFailWithNetworkError:error];
			}
		}
	}
	if (downloadData == nil) {
		downloadData = [[NSMutableData alloc] init];
	} else {
		NSMutableData *theData = self.downloadData;
		[theData setLength:0];
	}
	//downloadLength = [response expectedContentLength];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.downloadData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (connection != downloadConnection) return;
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	isLoading = NO;
	self.downloadConnection = nil;
	
	if (downloadCompleteAction != nil)
		[self performSelector: downloadCompleteAction withObject: downloadData];
	self.downloadData = nil;
}	

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if (connection != downloadConnection) return;
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	self.downloadConnection = nil;
	self.downloadData = nil;
	isLoading = NO;
	//[statusLabel setText:[error localizedDescription]];
	//NSLog (@"Error: %@", error);
	
	if ([delegate respondsToSelector:@selector(twitter:didFailWithNetworkError:)]) {
		[delegate twitter:self didFailWithNetworkError:error];
	}
}

#pragma mark -

- (void) saveAccounts {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [NSKeyedArchiver archivedDataWithRootObject:accounts] forKey: @"twitterAccounts"];
	[defaults setObject: self.currentAccount.screenName forKey: @"currentAccount"];
}

#pragma mark -

- (NSString*) URLEncodeString: (NSString*) aString {
	NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aString, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
 	return [result autorelease];
}

- (NSURL*) URLWithBase: (NSString*) baseString query: (NSDictionary*) parameters {
	NSMutableString *s = [[NSMutableString alloc] initWithString: baseString];
	BOOL firstParameter = YES;
	
	if ([parameters count] > 0) {
		NSArray *allKeys = [parameters allKeys];
		NSString *key, *value;
		for (key in allKeys) {
			if (firstParameter) {
				[s appendString:@"?"];
				firstParameter = NO;
			} else {
				[s appendString:@"&"];
			}
			value = [self URLEncodeString: [parameters objectForKey:key]];
			[s appendFormat: @"%@=%@", key, value];
		}
	}
	
	NSURL *url = [NSURL URLWithString:s];
	[s release];
	return url;
}

@end
