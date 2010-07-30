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
#import "TwitterStatusUpdate.h"

#import "Analyze.h"
#import "AccountsViewController.h"
#import "AllStarsViewController.h"

#import "TwitterLoadTimelineAction.h"


const float kDelayBeforeEnteringShuffleMode = 60.0;


@interface RootViewController (PrivateMethods)
- (void) startLoadingCurrentTimeline;
@end

@implementation RootViewController
@synthesize accountsButton;


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
		timelineHTMLController.account = [twitter accountWithScreenName:currentAccountScreenName];
	} else {
		if (twitter.accounts.count > 0) 
			timelineHTMLController.account = [twitter.accounts objectAtIndex: 0];
	}
}

- (AccountsViewController*) showAccounts:(id)sender {
	if ([self closeAllPopovers]) 
		return nil;
	AccountsViewController *accountsController = [[[AccountsViewController alloc] initWithTwitter:twitter] autorelease];
	accountsController.delegate = self;
	[self presentViewController:accountsController inNavControllerInPopoverFromItem:sender];
	return accountsController;
}

#pragma mark UIWebView delegate methods

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	if ([[url scheme] isEqualToString:@"action"]) {
		//TwitterAccount *account = [twitter currentAccount];
		NSString *actionName = [url resourceSpecifier];
		
		// Tabs
		if ([actionName hasPrefix:@"login"]) { // Log in
			[self login:accountsButton];
			return NO;
		}
	}
	
	return [super webView:aWebView shouldStartLoadWithRequest:request navigationType:navigationType];
}

#pragma mark Popover delegate methods

- (void) didSelectAccount:(TwitterAccount*)anAccount {
	timelineHTMLController.account = anAccount;
	[self closeAllPopovers];
	if (timelineHTMLController.webViewHasValidHTML) {
		[self.webView setDocumentElement:@"current_account" innerHTML:[timelineHTMLController currentAccountHTML]];
		[self.webView scrollToTop];
	}
	[timelineHTMLController selectHomeTimeline];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: timelineHTMLController.account.screenName forKey: @"currentAccount"];
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewDidLoad {
	[timelineHTMLController selectHomeTimeline];	
	[super viewDidLoad];
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setNavigationBarHidden: YES animated: NO];
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (timelineHTMLController.account == nil) {
		[self login: accountsButton];
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
		ListsViewController *lists = [[[ListsViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
		lists.currentLists = timelineHTMLController.account.lists;
		lists.currentSubscriptions = timelineHTMLController.account.listSubscriptions;
		lists.delegate = self;
		[self presentViewController:lists inNavControllerInPopoverFromItem:sender];
	}
}

- (IBAction) allstars: (id) sender {
	if ([self closeAllPopovers] == NO) {
		NSArray *messages = [timelineHTMLController.account.homeTimeline messagesWithLimit:96];
		
		AllStarsViewController *controller = [[[AllStarsViewController alloc] initWithTimeline:messages] autorelease];
		[self presentModalViewController:controller animated:YES];
		[controller startDelayedShuffleModeAfterInterval:kDelayBeforeEnteringShuffleMode];
	}
}

- (IBAction) analyze: (id) sender {
	if ([self closeAllPopovers] == NO) {
		Analyze *c = [[[Analyze alloc] initWithAccount:timelineHTMLController.account] autorelease];
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
			[self presentViewController:c inNavControllerInPopoverFromItem:sender];
		} else {
			[self presentModalViewController:c animated:YES];
		}
	}
}

@end

