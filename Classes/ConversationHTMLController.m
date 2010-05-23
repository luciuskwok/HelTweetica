//
//  ConversationHTMLController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

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


#pragma mark TwitterActions

- (void)loadMessage:(NSNumber*)messageIdentifier {
	// Check if message is already loaded
	TwitterMessage *message = [twitter statusWithIdentifier:messageIdentifier];
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
	NSSet *replies = [twitter statusesInReplyToStatusIdentifier:messageIdentifier];
	[timelineSet unionSet:replies];
	[timeline.messages setArray: [timelineSet allObjects]];
	
	// Sort by message id
	NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
	[timeline.messages sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
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
	if (!loadingComplete && timeline.messages.count > 0) {
		TwitterMessage *lastMessage = [timeline.messages lastObject];
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
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"conversation-template" ofType:@"html"];
	NSString *html = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
	if (error != nil)
		NSLog (@"Error loading conversation-template.html: %@", [error localizedDescription]);
	return html;
}

- (NSString *)tweetRowTemplateForRow:(int)row {
	TwitterMessage *message = [timeline.messages objectAtIndex:row];
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
