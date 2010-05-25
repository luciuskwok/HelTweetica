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
@synthesize followButton, screenName;


- (id)initWithTwitter:(Twitter*)aTwitter account:(TwitterAccount*)anAccount screenName:(NSString*)aScreenName {
	self = [super initWithWindowNibName:@"UserWindow"];
	if (self) {
		appDelegate = [NSApp delegate];
		self.screenName = aScreenName;
		
		// Timeline HTML Controller generates the HTML from a timeline
		UserPageHTMLController *controller = [[[UserPageHTMLController alloc] init] autorelease];
		controller.twitter = aTwitter;
		controller.account = anAccount;
		controller.delegate = self;
		self.htmlController = controller;
}
	return self;
}

- (void)dealloc {
	[screenName release];
	[super dealloc];
}

- (void)windowDidLoad {
	if (screenName) {
		[self loadUserWithScreenName:screenName];
	} else {
		[searchField becomeFirstResponder];
	}

	htmlController.webView = self.webView;
	[htmlController loadWebView];
}

- (void)loadUserWithScreenName:(NSString*)aScreenName {
	if (aScreenName == nil) return;
	
	self.screenName = aScreenName;
	
	// Set up window and toolbar.
	[[self window] setTitle:aScreenName];
	[timelineSegmentedControl setSelectedSegment:0];
	[followButton setTitle:@"—"];
	[followButton setEnabled:NO];
	
	// Load user from Twitter cache. If user was not found in cache, create a temporary user object.
	TwitterUser *user = [htmlController.twitter userWithScreenName:aScreenName];
	if (user == nil) {
		user = [[[TwitterUser alloc] init] autorelease];
		user.screenName = aScreenName;
		user.identifier = [NSNumber numberWithInt: -1]; // -1 signifies that user info has not been loaded
	}

	// Set up HTML controller.
	UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
	controller.user = user;
	[controller selectUserTimeline:aScreenName];
	[controller rewriteUserInfoArea];
	self.lists = user.lists;
	self.subscriptions = user.listSubscriptions;
	
	// Load the following/follower status for users other than the account's own.
	if ([controller.account.screenName isEqualToString:aScreenName] == NO) 
		[controller loadFriendStatus:aScreenName];
	
	// Load the latest user info.
	[controller loadUserInfo];
	
	// Load user's lists.
	[self reloadListsMenu];
	[self loadListsOfUser:controller.user.screenName];
}

- (void)searchForQuery:(NSString*)aQuery {
	// Go to username instead of searching Twitter content.
	self.screenName = aQuery;
	[self loadUserWithScreenName:aQuery];
}	


#pragma mark WebView policy delegate

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id)listener {
	
	BOOL handled = NO;
	
	if ([[[request URL] scheme] isEqualToString:@"action"]) {
		NSString *actionName = [[request URL] resourceSpecifier];
		UserPageHTMLController *controller = (UserPageHTMLController *)htmlController;
		
		// Tabs
		if ([actionName hasPrefix:@"user"]) { // Home Timeline
			NSString *aScreenName = [actionName lastPathComponent];
			if ([aScreenName caseInsensitiveCompare:controller.user.screenName] == NSOrderedSame) {
				[controller selectUserTimeline:aScreenName];
			} else {
				[self showUserPage:aScreenName];
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
