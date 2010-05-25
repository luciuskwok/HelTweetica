//
//  UserWindowController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/24/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UserWindowController.h"
#import "UserPageHTMLController.h"

#import "Twitter.h"
#import "TwitterAccount.h"
#import "TwitterUser.h"


@implementation UserWindowController
@synthesize followButton;


- (id)initWithTwitter:(Twitter*)aTwitter account:(TwitterAccount*)account user:(TwitterUser*)user {
	self = [super initWithWindowNibName:@"UserWindow"];
	if (self) {
		appDelegate = [NSApp delegate];
		
		// Timeline HTML Controller generates the HTML from a timeline
		UserPageHTMLController *controller = [[[UserPageHTMLController alloc] init] autorelease];
		controller.twitter = aTwitter;
		controller.account = account;
		controller.user = user;
		controller.delegate = self;
		[controller selectUserTimeline:user.screenName];
		self.htmlController = controller;

		self.lists = user.lists;
		self.subscriptions = user.listSubscriptions;
}
	return self;
}

- (void)dealloc {
	[super dealloc];
}

- (void)windowDidLoad {
	htmlController.webView = self.webView;
	[htmlController loadWebView];
	
	UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;

	if (controller.user.screenName == nil)
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");
	
	// Download the latest tweets from this user.
	[timelineSegmentedControl setSelectedSegment:0];
	
	// Get the following/follower status, but only if it's a different user from the account.
	if ([controller.account.screenName isEqualToString:controller.user.screenName] == NO) 
		[controller loadFriendStatus:controller.user.screenName];
	
	// Get the latest user info
	[controller loadUserInfo];

	// Set window title to user name
	NSString *screenName = controller.user.screenName;
	if (screenName) 
		[[self window] setTitle:screenName];
	
	[self reloadListsMenu];
	
	// Start loading lists
	[self loadListsOfUser:controller.user.screenName];
}

#pragma mark WebView policy delegate

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id)listener {
	
	BOOL handled = NO;
	
	if ([[[request URL] scheme] isEqualToString:@"action"]) {
		NSString *actionName = [[request URL] resourceSpecifier];
		UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
		
		// Tabs
		if ([actionName hasPrefix:@"user"]) { // Home Timeline
			NSString *screenName = [actionName lastPathComponent];
			if ([screenName caseInsensitiveCompare:controller.user.screenName] == NSOrderedSame) {
				[controller selectUserTimeline:controller.user.screenName];
			} else {
				[self showUserPage:screenName];
			}
			handled = YES;
		} else if ([actionName isEqualToString:@"favorites"]) { // Favorites
			[controller selectFavoritesTimeline:controller.user.screenName];
			handled = YES;
		}
	}
	
	if (handled) {
		[listener ignore];
	} else {
		[super webView:sender decidePolicyForNavigationAction:actionInformation request:request frame:frame decisionListener:listener];
	}
}

#pragma mark UserPageHTMLController delegate

- (void)didSelectTimeline:(TwitterTimeline *)timeline {
	UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
	int index = -1;
	if (timeline == controller.user.statuses) {
		index = 0;
	} else if (timeline == controller.user.favorites) {
		index = 1;
	}
	if (index >= 0) {
		[timelineSegmentedControl setSelectedSegment:index];
	} else {
		// Deselect
		index = [timelineSegmentedControl selectedSegment];
		if (index >= 0)
			[timelineSegmentedControl setSelected:NO forSegment:index];
	}
}

- (void)didUpdateFriendshipStatusWithAccountFollowsUser:(BOOL)accountFollowsUser userFollowsAccount:(BOOL)userFollowsAccount {
	// Change title of follow/unfollow button in toolbar
	followButton.title = accountFollowsUser ? NSLocalizedString (@"Unfollow", @"button") : NSLocalizedString (@"Follow", @"button");
	followButton.target = self;
	followButton.action = accountFollowsUser ? @selector(unfollow:) : @selector(follow:);
}

#pragma mark Actions

- (IBAction)selectTimelineWithSegmentedControl:(id)sender {
	int index = [sender selectedSegment];
	switch (index) {
		case 0:
			[self homeTimeline:nil];
			break;
		case 1:
			[self favorites:nil];
			break;
		default:
			break;
	}
}

- (IBAction)homeTimeline:(id)sender {
	UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
	[controller selectUserTimeline:controller.user.screenName];
}

- (IBAction)favorites:(id)sender {
	UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
	[controller selectFavoritesTimeline:controller.user.screenName];
}

- (IBAction)follow:(id)sender {
	UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
	[controller follow];
}

- (IBAction)unfollow:(id)sender {
	UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
	[controller unfollow];
}


@end
