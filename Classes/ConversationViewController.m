    //
//  ConversationViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ConversationViewController.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterTimeline.h"


@implementation ConversationViewController
@synthesize selectedMessageIdentifier;


// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithMessageIdentifier:(NSNumber*)anIdentifier {
	self = [super initWithNibName:@"Conversation" bundle:nil];
	if (self) {
		self.selectedMessageIdentifier = anIdentifier;
		self.customPageTitle = NSLocalizedString (@"The <b>Conversation</b>", @"title");
		self.currentTimeline = [[[TwitterTimeline alloc] init] autorelease];
		maxTweetsShown = 1000; // Allow for a larger limit for searches.
		currentTimeline.gaps = nil; // Ignore gaps
		[self loadMessage:anIdentifier];
		
		// Special template to highlight the selected message. tweet-row-highlighted-template.html
		NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
		NSError *error = nil;
		highlightedTweetRowTemplate = [[NSString alloc] initWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"tweet-row-highlighted-template.html"] encoding:NSUTF8StringEncoding error:&error];
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

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark TwitterActions

- (void)loadMessage:(NSNumber*)messageIdentifier {
	// Check if message is already loaded
	TwitterMessage *message = [twitter statusWithIdentifier:messageIdentifier];
	if (message) {
		[currentTimeline.messages addObject:message];
		[self loadInReplyToMessage: message];
	} else {
		NSString *twitterMethod = [NSString stringWithFormat:@"statuses/show/%@", messageIdentifier];
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:twitterMethod] autorelease];
		action.timeline = currentTimeline;
		action.completionAction = @selector(didLoadMessage:);
		action.completionTarget = self;
		[self startTwitterAction:action];
	}
	
	// Also load all cached replies to this message
	NSMutableSet *timelineSet = [NSMutableSet setWithArray:currentTimeline.messages];
	NSSet *replies = [twitter statusesInReplyToStatusIdentifier:messageIdentifier];
	[timelineSet unionSet:replies];
	[currentTimeline.messages setArray: [timelineSet allObjects]];
	
	// Sort by message id
	NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
	[currentTimeline.messages sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
}

- (void)loadingComplete {
	// No more messages
	loadingComplete = YES;
	[self rewriteTweetArea];
}

- (void)didLoadMessage:(TwitterLoadTimelineAction *)action {
	// Synchronized users and messages with Twitter cache.
	[twitter synchronizeStatusesWithArray:action.timeline.messages updateFavorites:YES];
	[twitter addUsers:action.users];
	
	// Load next message in conversation.
	if (!loadingComplete && currentTimeline.messages.count > 0) {
		TwitterMessage *lastMessage = [currentTimeline.messages lastObject];
		[self loadInReplyToMessage: lastMessage];
		if (webViewHasValidHTML) 
			[self rewriteTweetArea];	
	}
}

- (void)loadInReplyToMessage:(TwitterMessage*)message {
	NSNumber *identifier = message.inReplyToStatusIdentifier;
	if (identifier == nil && message.retweetedMessage != nil)
		identifier = message.retweetedMessage.inReplyToStatusIdentifier;
	
	if (identifier != nil) {
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

- (void)reloadCurrentTimeline {
	// Do nothing.
}

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// Select the tapped message
	self.selectedMessageIdentifier = identifier;
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
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSString *templateFile = [mainBundle stringByAppendingPathComponent:@"basic-template.html"];
	NSError *error = nil;
	NSMutableString *html  = [NSMutableString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&error];
	if (error) { NSLog (@"Error loading conversation-template.html: %@", [error localizedDescription]); }
	
	// Add any customization here.
	
	return html;
}

- (NSString *)tweetRowTemplateForRow:(int)row {
	TwitterMessage *message = [currentTimeline.messages objectAtIndex:row];
	if ([message.identifier isEqualToNumber:selectedMessageIdentifier])
		return highlightedTweetRowTemplate;
	return tweetRowTemplate;
}

- (NSString*) tweetAreaFooterHTML {
	NSString *result = @"";
	
	if (loadingComplete == NO) {
		result = loadingHTML;
	} else if (networkIsReachable == NO) {
		result = @"<div class='status'>No Internet connection.</div>";
	} else if (protectedUser) {
		result = @"<div class='status'>Protected message.</div>";
	} else if (messageNotFound) {
		result = @"<div class='status'>Message was deleted.</div>";
	} else if (currentTimeline.messages.count == 0) {
		result = @"<div class='status'>No messages.</div>";
	}
	
	return result;
}

@end
