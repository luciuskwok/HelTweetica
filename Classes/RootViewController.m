//
//  RootViewController.m
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


#import "RootViewController.h"
#import "TwitterAccount.h"
#import "TwitterTimeline.h"
#import "TwitterMessage.h"

#import "Analyze.h"
#import "AccountsViewController.h"
#import "AllStarsViewController.h"

#import "TwitterLoadTimelineAction.h"


#define kDelayBeforeEnteringShuffleMode 60.0


@interface RootViewController (PrivateMethods)
- (void) startLoadingCurrentTimeline;
@end

@implementation RootViewController
@synthesize accountsButton;


#define kTimelineIdentifier @"Timeline"
#define kMentionsIdentifier @"Mentions"
#define kDirectMessagesIdentifier @"Direct"
#define kFavoritesIdentifier @"Favorites"

- (void)dealloc {
	[accountsButton release];
	
	[currentPopover release];
	[currentActionSheet release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	self.accountsButton = nil;
}

- (void) awakeFromNib {
	[super awakeFromNib];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *currentAccountScreenName = [defaults objectForKey: @"currentAccount"];
	if (currentAccountScreenName) {
		self.currentAccount = [twitter accountWithScreenName:currentAccountScreenName];
	} else {
		if (twitter.accounts.count > 0) 
			self.currentAccount = [twitter.accounts objectAtIndex: 0];
	}
}

#pragma mark Twitter timeline selection

- (void) selectHomeTimeline {
	self.customTabName = kTimelineIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.
	
	self.currentTimeline = currentAccount.homeTimeline;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/home_timeline"] autorelease];
	[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"count"];
}

- (void) selectMentionsTimeline {
	self.customTabName = kMentionsIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.
	
	self.currentTimeline = currentAccount.mentions;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/mentions"] autorelease];
	[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"count"];
}

- (void) selectDirectMessageTimeline {
	self.customTabName = kDirectMessagesIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.
	
	self.currentTimeline = currentAccount.directMessages;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"direct_messages"] autorelease];
	[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"count"];
}

- (void) selectFavoritesTimeline {
	self.customTabName = kFavoritesIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.
	
	self.currentTimeline = currentAccount.favorites;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	// Favorites always loads 20 per page. Cannot change the count.
}

- (void)reloadRetweetsSince:(NSNumber*)sinceIdentifier toMax:(NSNumber*)maxIdentifier {
	if ([currentTimelineAction.twitterMethod isEqualToString:@"statuses/home_timeline"]) {
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/retweeted_by_me"] autorelease];
		if (sinceIdentifier) 
			[action.parameters setObject:sinceIdentifier forKey:@"since_id"];
		if (maxIdentifier) 
			[action.parameters setObject:maxIdentifier forKey:@"max_id"];
		[action.parameters setObject:defaultLoadCount forKey:@"count"];
		
		// Prepare action and start it. 
		action.timeline = currentTimeline.messages;
		action.completionTarget= self;
		action.completionAction = @selector(didReloadRetweets:);
		[self startTwitterAction:action];
	}
}

- (void)didReloadRetweets:(TwitterLoadTimelineAction *)action {
	// Synchronize timeline with Twitter cache.
	[twitter synchronizeStatusesWithArray:action.timeline updateFavorites:YES];
	[twitter addUsers:action.users];
	
	// Finished loading, so update tweet area and remove loading spinner.
	[self rewriteTweetArea];	
}

- (AccountsViewController*) showAccounts:(id)sender {
	if ([self closeAllPopovers]) 
		return nil;
	AccountsViewController *accountsController = [[[AccountsViewController alloc] initWithTwitter:twitter] autorelease];
	accountsController.delegate = self;
	[self presentContent: accountsController inNavControllerInPopoverFromItem: sender];
	return accountsController;
}

#pragma mark WebView updating

- (NSString*) currentAccountHTML {
	return [NSString stringWithFormat:@"<a href='action:user/%@'>%@</a>", currentAccount.screenName, currentAccount.screenName];
}

- (NSString*) tabAreaHTML {
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];
	
	int selectedTab = 0;
	if ([customTabName isEqualToString: kTimelineIdentifier] || (customTabName == nil)) {
		selectedTab = 1;
	} else if ([customTabName isEqualToString: kMentionsIdentifier]) {
		selectedTab = 2;
	} else if ([customTabName isEqualToString: kDirectMessagesIdentifier]) {
		selectedTab = 3;
	} else if ([customTabName isEqualToString: kFavoritesIdentifier]) {
		selectedTab = 4;
	} else {
		selectedTab = 5;
	}
	
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Timeline';\">Timeline</div>", (selectedTab == 1)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Mentions';\">Mentions</div>", (selectedTab == 2)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Direct';\">Direct</div>", (selectedTab == 3)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Favorites';\">Favorites</div>", (selectedTab == 4)? @"" : @"de"];
	if (selectedTab == 5)
		[html appendFormat:@"<div class='tab selected'>%@</div>", customTabName];
	
	return html;
}

- (void) rewriteTabArea {
	if (webViewHasValidHTML)
		[self.webView setDocumentElement:@"tab_area" innerHTML:[self tabAreaHTML]];
}

- (void) rewriteTweetArea {
	[self rewriteTabArea];
	[super rewriteTweetArea];
}

- (NSString*) webPageTemplate {
	// Load main template
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSString *templateFile = [mainBundle stringByAppendingPathComponent:@"main-template.html"];
	NSError *error = nil;
	NSMutableString *html  = [NSMutableString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&error];

	// Replace custom tags with HTML
	NSString *currentAccountHTML = @"";
	NSString *tabAreaHTML = @"";
	
	if (currentAccount.screenName != nil) {
		currentAccountHTML = [self currentAccountHTML];
		tabAreaHTML = [self tabAreaHTML];
	}
	
	// Replace custom tags with HTML
	[html replaceOccurrencesOfString:@"<currentAccountHTML/>" withString:currentAccountHTML options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"<tabAreaHTML/>" withString:tabAreaHTML options:0 range:NSMakeRange(0, html.length)];
	
	return html;
}

#pragma mark UIWebView delegate methods

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	if ([[url scheme] isEqualToString:@"action"]) {
		//TwitterAccount *account = [twitter currentAccount];
		NSString *actionName = [url resourceSpecifier];
		
		// Tabs
		if ([actionName isEqualToString:kTimelineIdentifier]) { // Home Timeline
			[self selectHomeTimeline];
			[self startLoadingCurrentTimeline];
			return NO;
		} else if ([actionName isEqualToString:kMentionsIdentifier]) { // Mentions
			[self selectMentionsTimeline];
			[self startLoadingCurrentTimeline];
			return NO;
		} else if ([actionName isEqualToString:kDirectMessagesIdentifier]) { // Direct Messages
			[self selectDirectMessageTimeline];
			[self startLoadingCurrentTimeline];
			return NO;
		} else if ([actionName isEqualToString:kFavoritesIdentifier]) { // Favorites
			[self selectFavoritesTimeline];
			[self startLoadingCurrentTimeline];
			return NO;
		} else if ([actionName hasPrefix:@"login"]) { // Log in
			[self login:accountsButton];
			return NO;
		}
	}
	
	return [super webView:aWebView shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
	[super webViewDidFinishLoad:aWebView];
}

#pragma mark Popover delegate methods

- (void) didSelectAccount:(TwitterAccount*)anAccount {
	self.currentAccount = anAccount;
	[self closeAllPopovers];
	if (webViewHasValidHTML) {
		[self.webView setDocumentElement:@"current_account" innerHTML:[self currentAccountHTML]];
		[self.webView scrollToTop];
	}
	[self selectHomeTimeline];
	[self startLoadingCurrentTimeline];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: self.currentAccount.screenName forKey: @"currentAccount"];
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewDidLoad {
	[self selectHomeTimeline];	
	[super viewDidLoad];
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setNavigationBarHidden: YES animated: NO];
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (currentAccount == nil) {
		[self login: accountsButton];
	} else {
		[refreshTimer invalidate];
		refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
	}
}

#pragma mark -
#pragma mark IBActions

- (IBAction) login: (id) sender {
	AccountsViewController *accountsController = [self showAccounts: sender];
	[accountsController add: sender];
}

- (IBAction) accounts: (id) sender {
	AccountsViewController *accountsController = [self showAccounts: sender];	
	if (twitter.accounts.count == 0) { // Automatically show the login screen if no accounts exist
		[accountsController add:sender];
	}
}

- (IBAction) lists: (id) sender {
	if ([self closeAllPopovers] == NO) {
		ListsViewController *lists = [[[ListsViewController alloc] initWithAccount:currentAccount] autorelease];
		lists.currentLists = currentAccount.lists;
		lists.currentSubscriptions = currentAccount.listSubscriptions;
		lists.delegate = self;
		[self presentContent: lists inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction) allstars: (id) sender {
	if ([self closeAllPopovers] == NO) {
		AllStarsViewController *controller = [[[AllStarsViewController alloc] initWithTimeline:currentAccount.homeTimeline.messages] autorelease];
		[self presentModalViewController:controller animated:YES];
		[controller startDelayedShuffleModeAfterInterval:kDelayBeforeEnteringShuffleMode];
	}
}

- (IBAction) analyze: (id) sender {
	if ([self closeAllPopovers] == NO) {
		Analyze *c = [[[Analyze alloc] init] autorelease];
		c.timeline = currentAccount.homeTimeline.messages;
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
			[self presentPopoverFromItem:sender viewController:c];
		} else {
			[self presentModalViewController:c animated:YES];
		}
	}
}

@end

