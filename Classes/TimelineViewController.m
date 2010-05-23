//
//  TimelineViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/3/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


// Imports
#import "TimelineViewController.h"
#import "LKWebView.h"
#import "HelTweeticaAppDelegate.h"

#import "ConversationViewController.h"
#import "UserPageViewController.h"
#import "WebBrowserViewController.h"
#import "SearchResultsViewController.h"

#import "TwitterTimeline.h"



@implementation TimelineViewController
@synthesize webView, composeButton;
@synthesize twitter, timelineHTMLController;
@synthesize currentPopover, currentActionSheet, currentAlert;


// Initializer for programmatically creating this
- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
	self = [super initWithNibName:nibName bundle:nibBundle];
	if (self) {
		// Do all the setup that awakeFromNib does
		[self awakeFromNib];
	}
	return self;
}

// Initializer for loading from nib
- (void) awakeFromNib {
	appDelegate = [[UIApplication sharedApplication] delegate]; // Use Twitter instance from app delegate
	self.twitter = appDelegate.twitter;
	
	// Timeline HTML Controller generates the HTML from a timeline
	self.timelineHTMLController = [[[TimelineHTMLController alloc] init] autorelease];
	timelineHTMLController.twitter = twitter;
	timelineHTMLController.delegate = self;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
	webView.delegate = nil;
	self.webView = nil;
	self.composeButton = nil;
}

- (void)dealloc {
	webView.delegate = nil;
	[webView release];
	[composeButton release];
	
	[twitter release];
	[timelineHTMLController release];
	
	currentPopover.delegate = nil;
	[currentPopover release];
	currentActionSheet.delegate = nil;
	[currentActionSheet release];
	currentAlert.delegate = nil;
	[currentAlert release];

	[super dealloc];
}

#pragma mark View lifecycle

- (void) viewDidLoad {
	[super viewDidLoad];
	timelineHTMLController.webView = self.webView;
	[timelineHTMLController loadWebView];
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[timelineHTMLController invalidateRefreshTimer];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


#pragma mark IBActions

- (IBAction)close:(id)sender {
	[self closeAllPopovers];
	[self.navigationController popViewControllerAnimated: YES];
}

- (IBAction) search: (id) sender {
	if ([self closeAllPopovers] == NO) {
		SearchViewController *search = [[[SearchViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
		search.delegate = self;
		[self presentContent: search inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction) goToUser:(id)sender {
	if ([self closeAllPopovers] == NO) { 
		GoToUserViewController *vc = [[[GoToUserViewController alloc] initWithTwitter:twitter] autorelease];
		vc.delegate = self;
		[self presentContent:vc inNavControllerInPopoverFromItem:sender];
	}
}

- (IBAction) reloadData: (id) sender {
	timelineHTMLController.suppressNetworkErrorAlerts = NO;
	[self.webView scrollToTop];
	[timelineHTMLController loadTimeline:timelineHTMLController.timeline];
}

#pragma mark Compose

- (IBAction)compose:(id)sender {
	if ([self closeAllPopovers] == NO) {
		ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
		[compose loadFromUserDefaults];
		compose.delegate = self;
		[self presentContent: compose inNavControllerInPopoverFromItem: sender];
	}
}	

- (void)retweet:(NSNumber*)identifier {
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	if (message == nil) return;
	
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
	[compose loadFromUserDefaults];
	compose.delegate = self;
	if (message != nil) {
		// Replace current message content with retweet. In a future version, save the existing tweet as a draft and make a new tweet with this text.
		compose.messageContent = [NSString stringWithFormat:@"RT @%@: %@", message.screenName, message.content];
		compose.originalRetweetContent = compose.messageContent;
		compose.inReplyTo = identifier;
	}
	
	[self closeAllPopovers];
	[self presentContent: compose inNavControllerInPopoverFromItem: composeButton];
}

- (void) replyToMessage: (NSNumber*)identifier {
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
	[compose loadFromUserDefaults];
	compose.delegate = self;
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	
	// Insert @username in beginning of message. This preserves any other people being replied to.
	if (message != nil) {
		NSString *replyUsername = message.screenName;
		if (compose.messageContent != nil) {
			compose.messageContent = [NSString stringWithFormat:@"@%@ %@", replyUsername, compose.messageContent];
		} else {
			compose.messageContent = [NSString stringWithFormat:@"@%@ ", replyUsername];
		}
		compose.inReplyTo = identifier;
		compose.originalRetweetContent = nil;
		compose.newStyleRetweet = NO;
	}
	
	[self closeAllPopovers];
	[self presentContent: compose inNavControllerInPopoverFromItem: composeButton];
}

- (void) directMessageWithTweet:(NSNumber*)identifier {
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
	[compose loadFromUserDefaults];
	compose.delegate = self;
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	
	// Insert d username in beginnig of message. This preserves any other people being replied to.
	if (message != nil) {
		NSString *replyUsername = message.screenName;
		if (compose.messageContent != nil) {
			compose.messageContent = [NSString stringWithFormat:@"d %@ %@", replyUsername, compose.messageContent];
		} else {
			compose.messageContent = [NSString stringWithFormat:@"d %@ ", replyUsername];
		}
		compose.inReplyTo = identifier;
		compose.originalRetweetContent = nil;
	}
	
	[self closeAllPopovers];
	[self presentContent: compose inNavControllerInPopoverFromItem: composeButton];
}


#pragma mark Popovers

- (BOOL)closeAllPopovers {
	// Returns YES if any popovers were visible and closed.
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		// Close any action sheets
		if (currentActionSheet != nil) {
			[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
			self.currentActionSheet = nil;
			return YES;
		}
		
		// If a popover is already shown, close it. 
		if (currentPopover != nil) {
			[currentPopover dismissPopoverAnimated:YES];
			self.currentPopover = nil;
			return YES;
		}
	}
	return NO;
}

- (void)popoverControllerDidDismissPopover: (UIPopoverController *) popoverController {
	self.currentPopover = nil;
}

- (UIPopoverController*) presentPopoverFromItem:(UIBarButtonItem*)item viewController:(UIViewController*)vc {
	// Present popover
	UIPopoverController *popover = [[[NSClassFromString(@"UIPopoverController") alloc] initWithContentViewController:vc] autorelease];
	popover.delegate = self;
	[popover presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	self.currentPopover = popover;
	return popover;
}	

- (void) presentContent: (UIViewController*) contentViewController inNavControllerInPopoverFromItem: (UIBarButtonItem*) item {
	UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController: contentViewController] autorelease];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[self presentPopoverFromItem:item viewController:navController];
	} else { // iPhone
		navController.navigationBar.barStyle = UIBarStyleBlack;
		[self presentModalViewController:navController animated:YES];
	}
}

#pragma mark View Controllers to push

- (void) showUserPage:(NSString*)screenName {
	[self closeAllPopovers];
	
	// Use a custom timeline showing the user's tweets, but with a big header showing the user's info.
	TwitterUser *user = [twitter userWithScreenName:screenName];
	if (user == nil) {
		// Create an empty user and add it to the Twitter set
		user = [[[TwitterUser alloc] init] autorelease];
		user.screenName = screenName;
		user.identifier = [NSNumber numberWithInt: -1]; // -1 signifies that user info has not been loaded
	}
	
	// Show user page
	UserPageViewController *vc = [[[UserPageViewController alloc] initWithTwitterUser:user] autorelease];
	vc.timelineHTMLController.account = self.timelineHTMLController.account;
	[self.navigationController pushViewController: vc animated: YES];
}

- (void) searchForQuery:(NSString*)query {
	[self closeAllPopovers];
	SearchResultsViewController *vc = [[[SearchResultsViewController alloc] initWithQuery:query] autorelease];
	vc.timelineHTMLController.account = self.timelineHTMLController.account;
	[self.navigationController pushViewController: vc animated: YES];
}	

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// Show conversation page
	ConversationViewController *vc = [[[ConversationViewController alloc] initWithMessageIdentifier:identifier] autorelease];
	vc.timelineHTMLController.account = self.timelineHTMLController.account;
	[self.navigationController pushViewController: vc animated: YES];
}

- (void) showWebBrowserWithURLRequest:(NSURLRequest*)request {
	// Push a separate web browser for links
	WebBrowserViewController *vc = [[[WebBrowserViewController alloc] initWithURLRequest:request] autorelease];
	[self.navigationController pushViewController: vc animated: YES];
}	


#pragma mark UIWebView delegate methods

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	// Actions
	if ([[url scheme] isEqualToString:@"action"]) {
		NSString *actionName = [url resourceSpecifier];
		NSNumber *messageIdentifier = [timelineHTMLController number64WithString:[actionName lastPathComponent]];
		
		 if ([actionName hasPrefix:@"retweet"]) { // Retweet message
			[self retweet: messageIdentifier];
		} else if ([actionName hasPrefix:@"reply"]) { // Public reply to the sender
			[self replyToMessage:messageIdentifier];
		} else if ([actionName hasPrefix:@"dm"]) { // Direct message the sender
			[self directMessageWithTweet:messageIdentifier];
		} else if ([actionName hasPrefix:@"user"]) { // Show user page
			[self showUserPage:[actionName lastPathComponent]];
		} else if ([actionName hasPrefix:@"search"]) { // Show search page
			[self searchForQuery:[[actionName lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		} else if ([actionName hasPrefix:@"conversation"]) { // Show more info on the tweet
			[self showConversationWithMessageIdentifier:messageIdentifier];
		} else {
			[timelineHTMLController handleWebAction:actionName];
		}
		
		return NO;
	} else if ([[url scheme] hasPrefix:@"http"]) {
		// Catch twitter.com status links
		NSNumber *messageIdentifier = nil;
		if ([[url host] hasSuffix:@"twitter.com"]) {
			NSArray *pathComponents = [[url path] componentsSeparatedByString:@"/"];
			if (pathComponents.count == 4 && [[pathComponents objectAtIndex:2] isEqualToString:@"status"]) {
				messageIdentifier = [timelineHTMLController number64WithString:[[url path] lastPathComponent]];
			}
		}
		
		if (messageIdentifier != nil) {
			[self showConversationWithMessageIdentifier:messageIdentifier];
		} else {
			// Push a separate web browser for links
			[self showWebBrowserWithURLRequest:request];
		}
		
		return NO;
	}
	
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView {
	[appDelegate incrementNetworkActionCount];
	timelineHTMLController.webViewHasValidHTML = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
	[appDelegate decrementNetworkActionCount];
	if (!webViewHasFinishedLoading) {
		webViewHasFinishedLoading = YES;

		// Automatically reload the current timeline over the network if this is the first time the web view is loaded.
		timelineHTMLController.suppressNetworkErrorAlerts = YES;
		[timelineHTMLController loadTimeline:timelineHTMLController.timeline];
	}
	
	// Hide Loading spinner if there are no actions
	if (timelineHTMLController.actions.count == 0) {
		[timelineHTMLController setLoadingSpinnerVisibility:NO];
	}
}

- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error {
	[appDelegate decrementNetworkActionCount];
	
	if ([error code] != -999) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString localizedStringWithFormat:@"Error %d", [error code]] message:[NSString localizedStringWithFormat:@"The page could not be loaded: \"%@\"", [error localizedDescription]] delegate:nil cancelButtonTitle:[NSString localizedStringWithFormat:@"OK"] otherButtonTitles:nil];
		[alert show];
		[alert release];
		timelineHTMLController.noInternetConnection = YES;
	}
}

#pragma mark Popover delegate methods

- (void) compose:(ComposeViewController*)aCompose didSendMessage:(NSString*)text inReplyTo:(NSNumber*)inReplyTo {
	[self closeAllPopovers];
	[timelineHTMLController updateStatus:text inReplyTo:inReplyTo];
}

- (void) compose:(ComposeViewController*)aCompose didRetweetMessage:(NSNumber*)identifier {
	[self closeAllPopovers];
	[timelineHTMLController retweet:identifier];
	
}

- (void) lists:(ListsViewController*)lists didSelectList:(TwitterList*)list {
	[self closeAllPopovers];
	[timelineHTMLController loadList:list];
}


- (void) search:(SearchViewController*)search didRequestQuery:(NSString*)query {
	[self searchForQuery:query];
}


#pragma mark Alert view

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	if (self.currentAlert == nil) { // Don't show another alert if one is already up.
		self.currentAlert = [[[UIAlertView alloc] initWithTitle:aTitle message:aMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[currentAlert show];
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	self.currentAlert = nil;
}


@end
