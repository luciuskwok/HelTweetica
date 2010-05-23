    //
//  UserPageViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UserPageViewController.h"
#import "Twitter.h"
#import "TwitterTimeline.h"
#import "TwitterUser.h"
#import "WebBrowserViewController.h"

#import "TwitterLoadTimelineAction.h"

#import "UserPageHTMLController.h"


// Tag used to identify Follow/Unfollow button in Toolbar
#define kFollowButtonTag 69
#define kFollowButtonPositionFromEnd 2


@implementation UserPageViewController
@synthesize topToolbar, user;


- (id)initWithTwitterUser:(TwitterUser*)aUser {
	self = [super initWithNibName:@"UserPage" bundle:nil];
	if (self) {
		self.user = aUser;
		
		// Replace HTML controller with specific one for User Pages
		UserPageHTMLController *controller = [[[UserPageHTMLController alloc] init] autorelease];
		controller.twitter = twitter;
		controller.user = aUser;
		controller.delegate = self;
		self.timelineHTMLController = controller;
	}
	return self;
}

- (void)dealloc {
	[topToolbar release];
	[user release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	self.topToolbar = nil;
}


#pragma mark UserPageHTMLController delegate

- (void)didUpdateFriendshipStatusWithAccountFollowsUser:(BOOL)accountFollowsUser userFollowsAccount:(BOOL)userFollowsAccount {
	// Insert follow/unfollow button in toolbar
	
	SEL buttonAction = accountFollowsUser ? @selector(unfollow:) : @selector(follow:);
	NSString *buttonTitle = accountFollowsUser ? NSLocalizedString (@"Unfollow", @"button") : NSLocalizedString (@"Follow", @"button");
	NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:self.topToolbar.items];
	
	// Remove any existing Follow/Unfollow buttons
	int index;
	for (index = 0; index < toolbarItems.count; index++) {
		UIBarItem *item = [toolbarItems objectAtIndex:index];
		if (item.tag == kFollowButtonTag) {
			[toolbarItems removeObjectAtIndex:index];
			break;
		}
	}
	
	// Only add button if the friend status is valid
	if (![timelineHTMLController.account.screenName isEqualToString:user.screenName]) {
		index = toolbarItems.count - kFollowButtonPositionFromEnd; // Position two from end
		UIBarButtonItem *followButton = [[[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStyleBordered target:self action:buttonAction] autorelease];
		followButton.tag = kFollowButtonTag;
		[toolbarItems insertObject:followButton atIndex:index];
	}
	
	[topToolbar setItems:toolbarItems animated:YES];
}

#pragma mark IBActions

- (IBAction) lists: (id) sender {
	if ([self closeAllPopovers] == NO) {
		ListsViewController *lists = [[[ListsViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
		lists.screenName = self.user.screenName;
		lists.currentLists = self.user.lists;
		lists.currentSubscriptions = self.user.listSubscriptions;
		lists.delegate = self;
		[self presentContent: lists inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction)follow:(id)sender {
	UserPageHTMLController *htmlController = (UserPageHTMLController *)timelineHTMLController;
	[htmlController follow];
}

- (IBAction)unfollow:(id)sender {
	UserPageHTMLController *htmlController = (UserPageHTMLController *)timelineHTMLController;
	[htmlController unfollow];
}



#pragma mark Web view delegate methods

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	if ([[url scheme] isEqualToString:@"action"]) {
		NSString *actionName = [url resourceSpecifier];
		UserPageHTMLController *htmlController = (UserPageHTMLController *)self.timelineHTMLController;
		
		// Tabs
		if ([actionName hasPrefix:@"user"]) { // Home Timeline
			NSString *screenName = [actionName lastPathComponent];
			if ([screenName caseInsensitiveCompare:user.screenName] == NSOrderedSame) {
				[htmlController selectUserTimeline:user.screenName];
			} else {
				[self showUserPage:screenName];
			}
			return NO;
		} else if ([actionName isEqualToString:@"favorites"]) { // Favorites
			[htmlController selectFavoritesTimeline:user.screenName];
			return NO;
		}
	}
	
	return [super webView:aWebView shouldStartLoadWithRequest:request navigationType:navigationType];
}


#pragma mark View lifecycle

- (void)viewDidLoad {
 	if (user.screenName == nil)
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");
	
	// Download the latest tweets from this user.
	//suppressNetworkErrorAlerts = YES;
	UserPageHTMLController *htmlController = (UserPageHTMLController *)timelineHTMLController;
	[htmlController selectUserTimeline:user.screenName];
	
	// Get the following/follower status, but only if it's a different user from the account.
	if ([timelineHTMLController.account.screenName isEqualToString:user.screenName] == NO) 
		[htmlController loadFriendStatus:user.screenName];
	
	// Get the latest user info
	[htmlController loadUserInfo];
	
	[super viewDidLoad];
	//screenNameButton.title = user.screenName;
	
}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.topToolbar = nil;
	//self.directMessageButton = nil;
}

@end
