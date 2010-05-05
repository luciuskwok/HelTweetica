    //
//  ConversationViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "ConversationViewController.h"
#import "TwitterLoadTimelineAction.h"


@implementation ConversationViewController

// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithMessageIdentifier:(NSNumber*)anIdentifier {
	self = [super initWithNibName:@"Conversation" bundle:nil];
	if (self) {
		self.customPageTitle = NSLocalizedString (@"The <b>Conversation</b>", @"title");
		self.currentTimeline = [NSMutableArray array];
		[self loadMessage:anIdentifier];
	}
	return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	shouldReloadAfterWebViewFinishesRendering = NO;
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
		[currentTimeline addObject:message];
		[self loadInReplyToMessage: message];
	} else {
		NSString *twitterMethod = [NSString stringWithFormat:@"statuses/show/%@", messageIdentifier];
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:twitterMethod] autorelease];
		action.timeline = currentTimeline;
		action.completionAction = @selector(didLoadMessage:);
		action.completionTarget = self;
		[self startTwitterAction:action];
	}
}

- (void)loadingComplete {
	// No more messages
	loadingComplete = YES;
	[self rewriteTweetArea];
}

- (void)didLoadMessage:(TwitterLoadTimelineAction *)action {
	// Synchronized users and messages with Twitter cache.
	[twitter synchronizeStatusesWithArray:action.timeline updateFavorites:YES];
	[twitter addUsers:action.users];
	
	// Load next message in conversation.
	if (currentTimeline.count > 0) {
		TwitterMessage *lastMessage = [currentTimeline lastObject];
		[self loadInReplyToMessage: lastMessage];
		[self rewriteTweetArea];	
	} else {
		// No more messages or an error occurred.
		NSLog (@"No messages were returned for the status id.");
		[self loadingComplete];
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

- (void) fireRefreshTimer:(NSTimer*)timer {
	// Refresh timer only to update timestamps.
	[self rewriteTweetArea];
	[refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
}

- (void)reloadCurrentTimeline {
	// Do nothing.
}

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// Do nothing because we're already in a conversation.
}

#pragma mark Web view

- (NSString*) webPageTemplate {
	// Load main template
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSString *templateFile = [mainBundle stringByAppendingPathComponent:@"conversation-template.html"];
	NSError *error = nil;
	NSMutableString *html  = [NSMutableString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&error];
	if (error) { NSLog (@"Error loading conversation-template.html: %@", [error localizedDescription]); }
	
	// Add any customization here.
	
	return html;
}

- (NSString*) tweetAreaFooterHTML {
	NSString *result = @"";
	
	if (loadingComplete == NO) {
		result = @"<div class='status'>Loading...</div>";
	} else if ([currentTimeline count] == 0) {
		result = @"<div class='status'>No messages.</div>";
	}
	
	return result;
}

@end
