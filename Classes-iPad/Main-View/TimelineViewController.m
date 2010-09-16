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
#import "SearchResultsViewController.h"

#import "TwitterTimeline.h"
#import "DeleteAlertDelegate.h"



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
	
	timelineHTMLController.delegate = nil;
	[timelineHTMLController release];
	
	currentPopover.delegate = nil;
	[currentPopover release];
	currentActionSheet.delegate = nil;
	[currentActionSheet release];
	[currentAlert setDelegate: nil];
	[currentAlert release];

	[super dealloc];
}

#pragma mark View lifecycle

- (void) viewDidLoad {
	[super viewDidLoad];
	
	// Interface Builder is very confused by the hybrid Mac/iOS header file for LKWebView, so set its delegate here.
	webView.delegate = self;
	
	timelineHTMLController.webView = self.webView;
	[timelineHTMLController loadWebView];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


#pragma mark IBActions

- (IBAction)close:(id)sender {
	timelineHTMLController.useRewriteHTMLTimer = NO;
	[timelineHTMLController invalidateRewriteHTMLTimer];
	timelineHTMLController.delegate = nil;

	[self closeAllPopovers];
	[self.navigationController popViewControllerAnimated: YES];
}

- (IBAction) search: (id) sender {
	if ([self closeAllPopovers])
		return;
	
	SearchViewController *search = [[[SearchViewController alloc] initWithAccount:timelineHTMLController.account] autorelease];
	search.delegate = self;
	[self presentViewController: search inNavControllerInPopoverFromItem: sender];
}

- (IBAction) goToUser:(id)sender {
	if ([self closeAllPopovers])
		return;

	GoToUserViewController *vc = [[[GoToUserViewController alloc] initWithTwitter:twitter] autorelease];
	vc.delegate = self;
	[self presentViewController:vc inNavControllerInPopoverFromItem:sender];
}

- (IBAction) reloadData: (id) sender {
	[timelineHTMLController refresh];
}

#pragma mark Compose

- (void)composeWithText:(NSString *)text {
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:timelineHTMLController.account withNibName:@"Compose"] autorelease];
	compose.delegate = self;
	
	if (text != nil)
		[[NSUserDefaults standardUserDefaults] setObject:text forKey:@"messageContent"];
	
	[self closeAllPopovers];
	[self presentModalViewController:compose animated:YES];
}

- (void)composeDirectMessageToScreenName:(NSString *)screenName {
	ComposeViewController *compose = [[ComposeViewController alloc] initDirectMessageWithAccount:timelineHTMLController.account to:screenName];
	compose.delegate = self;
		
	[self closeAllPopovers];
	[self presentModalViewController:compose animated:YES];
}

- (IBAction)compose:(id)sender {
	if ([self closeAllPopovers] == NO) {
		[self composeWithText:nil];
	}
}	

- (void)retweet:(NSNumber*)identifier {
	TwitterStatusUpdate *message = [twitter statusUpdateWithIdentifier: identifier];
	if (message == nil) return;

	// "RT @username: text"
	NSString *text = [NSString stringWithFormat:@"RT @%@: %@", message.userScreenName, message.text];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:text forKey:@"originalRetweetContent"];
	[defaults setObject:identifier forKey:@"inReplyTo"];
	
	[self composeWithText:text];
}

- (void) replyToMessage: (NSNumber*)identifier {
	TwitterStatusUpdate *message = [twitter statusUpdateWithIdentifier: identifier];
	if (message == nil) return;
	
	// "@username oldText"
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *oldText = [defaults objectForKey:@"messageContent"];
	NSString *text = [NSString stringWithFormat:@"@%@ ", message.userScreenName];
	if (oldText.length > 0)
		text = [text stringByAppendingString:oldText];
	[defaults removeObjectForKey:@"originalRetweetContent"];
	[defaults setObject:identifier forKey:@"inReplyTo"];
	
	[self composeWithText:text];
}

- (void)directMessageWithScreenName:(NSString*)screenName {
	if (screenName.length == 0) return;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:@"originalRetweetContent"];
	[defaults removeObjectForKey:@"inReplyTo"];
	
	[self composeDirectMessageToScreenName:screenName];
}

#pragma mark Delete

- (void)deleteStatusUpdate:(NSNumber *)identifier {
	// Alert that delete is permanent and cannot be undone.
	if (self.currentAlert == nil) { // Don't show another alert if one is already up.
		DeleteAlertDelegate *alert = [[[DeleteAlertDelegate alloc] init] autorelease];
		alert.identifier = identifier;
		alert.htmlController = timelineHTMLController;
		alert.delegate = self;
		[alert showAlert];
		self.currentAlert = alert;
	}
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

- (UIPopoverController*) presentViewController:(UIViewController*)vc inPopoverFromItem:(UIBarButtonItem*)item {
	// Present popover
	UIPopoverController *popover = [[[NSClassFromString(@"UIPopoverController") alloc] initWithContentViewController:vc] autorelease];
	popover.delegate = self;
	[popover presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	self.currentPopover = popover;
	return popover;
}	

- (void) presentViewController:(UIViewController*)viewController inNavControllerInPopoverFromItem: (UIBarButtonItem*) item {
	UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController: viewController] autorelease];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[self presentViewController:navController inPopoverFromItem:item];
	} else { // iPhone
		navController.navigationBar.barStyle = UIBarStyleBlack;
		[self presentModalViewController:navController animated:YES];
	}
}

- (void) composeDidFinish:(ComposeViewController*)aCompose {
	[timelineHTMLController loadTimeline:timelineHTMLController.timeline];
}

#pragma mark View Controllers to push

- (void) showUserPage:(NSString*)screenName {
	[self closeAllPopovers];
	if (screenName == nil) return;
	
	// Use a custom timeline showing the user's tweets, but with a big header showing the user's info.
	TwitterUser *user = [twitter userWithScreenName:screenName];
	if (user == nil) {
		// Create an empty user and add it to the Twitter set
		user = [[[TwitterUser alloc] init] autorelease];
		user.screenName = screenName;
		user.identifier = [NSNumber numberWithInt: -1]; // -1 signifies that user info has not been loaded
	}
	
	// Show user page
	UserPageViewController *vc = [[[UserPageViewController alloc] initWithTwitterUser:user account:timelineHTMLController.account] autorelease];
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
	vc.delegate = self;
	[self.navigationController pushViewController: vc animated: YES];
}	

- (void)browser:(WebBrowserViewController *)browser didFinishWithURLToTweet:(NSURL *)url {
	NSString *content = [NSString stringWithFormat:@"\n\n%@", [url absoluteString]];
	[self composeWithText:content];
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
		} else if ([actionName hasPrefix:@"delete"]) { // Delete status update
			[self deleteStatusUpdate:messageIdentifier];
		} else if ([actionName hasPrefix:@"dm"]) { // Direct message the sender
			[self directMessageWithScreenName:[actionName lastPathComponent]];
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
		// Send google.com links directly to Safari.
		if ([[url host] hasSuffix:@"maps.google.com"]) {
			[[UIApplication sharedApplication] openURL: url];
			return NO;
		}
		
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
		[timelineHTMLController loadTimeline:timelineHTMLController.timeline];
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

- (void) lists:(ListsViewController*)lists didSelectList:(TwitterList*)list {
	[self closeAllPopovers];
	[timelineHTMLController loadList:list];
}


- (void) search:(SearchViewController*)search didRequestQuery:(NSString*)query {
	[self searchForQuery:query];
}

- (void)didSelectScreenName:(NSString *)screenName {
	[self showUserPage:screenName];
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
