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
@synthesize selectedMessageIdentifier;

// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithMessageIdentifier:(NSNumber*)anIdentifier {
	self = [super init];
	if (self) {
		self.selectedMessageIdentifier = anIdentifier;
		self.customPageTitle = NSLocalizedString (@"The <b>Conversation</b>", @"title");
		self.timeline = [[[TwitterTimeline alloc] init] autorelease];
		self.timeline.gaps = nil; // Ignore gaps
		
		// Special template to highlight the selected message. tweet-row-highlighted-template.html
		NSError *error = nil;
		NSString *filePath = [[NSBundle mainBundle] pathForResource:@"tweet-row-highlighted-template" ofType:@"html"];
		highlightedTweetRowTemplate = [[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error] retain];
		if (error != nil)
			NSLog (@"Error loading tweet-row-highlighted-template.html: %@", [error localizedDescription]);
	}
	return self;
}

- (void)dealloc {
	[selectedMessageIdentifier release];
	[highlightedTweetRowTemplate release];
    [super dealloc];
}

#pragma mark Timeline selection

- (void)selectHomeTimeline {
	// Do nothing
}
	
#pragma mark TwitterActions

- (void)loadMessage:(NSNumber*)messageIdentifier {
	// Check if message is already loaded
	TwitterStatusUpdate *message = [twitter statusUpdateWithIdentifier:messageIdentifier];
	if (message) {
		[timeline.messages addObject:message];
		[self loadInReplyToMessage: message];
	} else {
		NSString *twitterMethod = [NSString stringWithFormat:@"statuses/show/%@", messageIdentifier];
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:twitterMethod] autorelease];
		action.timeline = timeline;
		action.completionAction = @selector(didLoadMessage:);
		action.completionTarget = self;
		[self startTwitterAction:action];
	}
	
	// Also load all cached replies to this message
	NSMutableSet *timelineSet = [NSMutableSet setWithArray:timeline.messages];
	NSSet *replies = [twitter statusUpdatesInReplyToStatusIdentifier:messageIdentifier];
	if (replies) {
		[timelineSet unionSet:replies];
		[timeline.messages setArray: [timelineSet allObjects]];
	}
	
	// Sort by date, then by identifier, descending.
	NSSortDescriptor *createdDateDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"createdDate" ascending:NO] autorelease];
	NSSortDescriptor *identifierDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
	[timeline.messages sortUsingDescriptors: [NSArray arrayWithObjects: createdDateDescriptor, identifierDescriptor, nil]];
}

- (void)loadingComplete {
	// No more messages
	loadingComplete = YES;
	[self rewriteTweetArea];
}

- (void)didLoadMessage:(TwitterLoadTimelineAction *)action {
	// Synchronized users and messages with Twitter cache.
	[twitter addStatusUpdates:action.loadedMessages];
	[twitter addUsers:action.users];
	[account addFavorites:action.favoriteMessages];
	
	// Load next message in conversation.
	if (!loadingComplete && timeline.messages.count > 0) {
		TwitterStatusUpdate *lastMessage = [timeline.messages lastObject];
		[self loadInReplyToMessage: lastMessage];
		if (webViewHasValidHTML) 
			[self rewriteTweetArea];	
	}
}

- (void)loadInReplyToMessage:(TwitterStatusUpdate*)message {
	NSNumber *identifier = message.inReplyToStatusIdentifier;
	
	if ([identifier longLongValue] > 10000) {
		// Load next message
		[self loadMessage:identifier];
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
	// Load main template
	NSError *error = nil;
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"basic-template" ofType:@"html"];
	NSString *html = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
	if (error != nil)
		NSLog (@"Error loading basic-template.html: %@", [error localizedDescription]);
	return html;
}

- (NSString *)tweetRowTemplateForRow:(int)row {
	TwitterStatusUpdate *message = [timeline.messages objectAtIndex:row];
	if ([message.identifier isEqualToNumber:selectedMessageIdentifier])
		return highlightedTweetRowTemplate;
	return tweetRowTemplate;
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
	} else if (timeline.messages.count == 0) {
		result = @"<div class='status'>No messages.</div>";
	}
	
	return result;
}

@end
