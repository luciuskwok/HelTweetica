//
//  ConversationHTMLController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ConversationHTMLController.h"

#import "TwitterLoadTimelineAction.h"



@implementation ConversationHTMLController
@synthesize selectedMessageIdentifier, relevantMessages;

// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithMessageIdentifier:(NSNumber*)anIdentifier {
	self = [super init];
	if (self) {
		self.customPageTitle = NSLocalizedString (@"The <b>Conversation</b>", @"title");

		self.selectedMessageIdentifier = anIdentifier;
		self.relevantMessages = [NSMutableSet set];
	}
	return self;
}

- (void)dealloc {
	[selectedMessageIdentifier release];
	[relevantMessages release];
	
	[super dealloc];
}

#pragma mark Timeline selection

- (void)selectHomeTimeline {
	// Do nothing
}
	
#pragma mark TwitterActions

- (void)loadCachedRepliesToMessage:(NSNumber*)messageIdentifier {
	NSSet *replies = [twitter statusUpdatesInReplyToStatusIdentifier:messageIdentifier];
	if (replies.count > 0)
		[relevantMessages unionSet:replies];
}

- (void)loadMessage:(NSNumber*)messageIdentifier {
	// Check if message is already loaded
	TwitterStatusUpdate *message = [twitter statusUpdateWithIdentifier:messageIdentifier];
	
	// Check if message, which is when the "in reply to" screen name and status identifier are both nil or both non-nil.
	BOOL hasReplyScreenName = (message.inReplyToScreenName != nil);
	BOOL hasReplyStatusIdentifier = (message.inReplyToStatusIdentifier != nil);
	BOOL valid = (hasReplyScreenName == hasReplyStatusIdentifier);
	
	if (valid && message) {
		[relevantMessages addObject:message];
		[self loadInReplyToMessage: message];
	} else {
		NSString *twitterMethod = [NSString stringWithFormat:@"statuses/show/%@", messageIdentifier];
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:twitterMethod] autorelease];
		action.completionAction = @selector(didLoadMessage:);
		action.completionTarget = self;
		[self startTwitterAction:action];
	}
	
	// Load all cached replies to this message
	[self loadCachedRepliesToMessage:messageIdentifier];
}

- (void)loadingComplete {
	// No more messages
	loadingComplete = YES;
	[self rewriteTweetArea];
}

- (void)didLoadMessage:(TwitterLoadTimelineAction *)action {
	// Add loaded message to array.
	[relevantMessages addObjectsFromArray:action.loadedMessages];
	
	// Synchronized users and messages with Twitter cache.
	[twitter addStatusUpdates:action.loadedMessages replaceExisting:YES];
	[twitter addUsers:action.users];
	[account addFavorites:action.favoriteMessages];
	
	// Load next message in conversation.
	if (!loadingComplete && relevantMessages.count > 0) {
		if (webViewHasValidHTML) 
			[self rewriteTweetArea];	
		TwitterStatusUpdate *lastMessage = [messages lastObject];
		[self loadInReplyToMessage: lastMessage];
	}
}

- (void)loadInReplyToMessage:(TwitterStatusUpdate*)message {
	// Load all cached replies to this message
	[self loadCachedRepliesToMessage:message.identifier];
	
	if ([message.inReplyToStatusIdentifier longLongValue] > 10000) {
		// Load next message
		[self loadMessage:message.inReplyToStatusIdentifier];
	} else {

		// No more messages
		[self loadingComplete];
	}
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	[super twitterAction:action didFailWithError:error];
	[self loadingComplete];
}

- (void) fireRefreshTimer:(NSTimer*)timer {
	// Refresh timer only to update timestamps.
	[self rewriteTweetArea];
}

- (void)handleTwitterStatusCode:(int)code {
	// Ignore all status codes while loading tweets and don't load any more tweets.
	switch (code) {
		case 403: protectedUser = YES; break;
		case 404: messageNotFound = YES; break;
		default: break;
	}
	if (code >= 400) 
		[self loadingComplete];
}

#pragma mark Web view

- (NSString*) webPageTemplate {
	return [self loadHTMLTemplate:@"basic-template"];
}

- (NSString *)styleForStatusUpdate:(TwitterStatusUpdate *)statusUpdate rowIndex:(int)rowIndex {
	NSString *style = [super styleForStatusUpdate:statusUpdate rowIndex:rowIndex];
	
	// Selection
	if ([statusUpdate.identifier isEqualToNumber:selectedMessageIdentifier])
		style = @"highlighted_tweet_row";
	
	return style;
}

- (NSString*) tweetAreaFooterHTML {
	NSString *result = @"";
	
	if (loadingComplete == NO) {
		result = loadingHTML;
	} else if (noInternetConnection) {
		result = @"<div class='status'>No Internet connection.</div>";
	} else if (protectedUser) {
		result = @"<div class='status'>Protected message.</div>";
	} else if (messageNotFound) {
		result = @"<div class='status'>Message was deleted.</div>";
	} else if (messages.count == 0) {
		result = @"<div class='status'>No messages.</div>";
	}
	
	return result;
}

- (void)rewriteTweetArea {
	// Set the messages to a list of messages sorted by date descending.
	// Sort by date, then by identifier, descending.
	NSSortDescriptor *createdDateDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"createdDate" ascending:NO] autorelease];
	NSSortDescriptor *identifierDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
	self.messages = [[relevantMessages allObjects] sortedArrayUsingDescriptors:[NSArray arrayWithObjects: createdDateDescriptor, identifierDescriptor, nil]];
	[super rewriteTweetArea];
}

@end
