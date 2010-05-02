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
#import "HelTweeticaAppDelegate.h"
#import "TwitterAccount.h"
#import "TwitterMessage.h"
#import "ComposeViewController.h"
#import "Analyze.h"
#import "WebBrowserViewController.h"
#import "AccountsViewController.h"
#import "ListsViewController.h"
#import "SearchViewController.h"
#import "AllStarsViewController.h"


#define kMaxNumberOfMessagesShown 800
#define kDelayBeforeEnteringShuffleMode 60.0


@interface RootViewController (PrivateMethods)
- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage;
- (void) replyToMessage:(NSNumber*)identifier;
- (void) directMessageWithTweet:(NSNumber*)identifier;
- (void) showTweet:(NSNumber*)identifier;
- (void) loadOlderMessages;
- (BOOL)closeAllPopovers;

- (void) setLoadingSpinnerVisibility:(BOOL)isVisible;

- (void) refreshWebView;
@end

@implementation RootViewController
@synthesize webView, accountsButton, composeButton, customPageTitle, selectedTabName;
@synthesize currentPopover, currentActionSheet, currentAlert;


#define kTimelineIdentifier @"Timeline"
#define kMentionsIdentifier @"Mentions"
#define kDirectMessagesIdentifier @"Direct"
#define kFavoritesIdentifier @"Favorites"

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[twitter release];
	[webView release];
	[accountsButton release];
	
	[customPageTitle release];
	[selectedTabName release];
	
	[currentPopover release];
	[currentActionSheet release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	//	self.navItem = nil;
	self.webView.delegate = nil;
	self.webView = nil;
	self.accountsButton = nil;
}

- (void) awakeFromNib {
	// Use Twitter instance from app delegate
	HelTweeticaAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	twitter = [appDelegate.twitter retain];
	twitter.delegate = self;
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(currentAccountDidChange:) name:@"currentAccountDidChange" object:nil];
	
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//selectedTab = [defaults integerForKey:@"selectedTab"];
}


#pragma mark -
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
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
		UIPopoverController *popover = [self presentPopoverFromItem:item viewController:navController];
		if ([contentViewController respondsToSelector:@selector (setPopover:)])
			[(id) contentViewController setPopover: popover];
	} else { // iPhone
		navController.navigationBar.barStyle = UIBarStyleBlack;
		[self presentModalViewController:navController animated:YES];
	}
}

- (AccountsViewController*) showAccounts:(id)sender {
	if ([self closeAllPopovers]) 
		return nil;
	AccountsViewController *accountsController = [[[AccountsViewController alloc] initWithTwitter:twitter] autorelease];
	[self presentContent: accountsController inNavControllerInPopoverFromItem: sender];
	return accountsController;
}

#pragma mark -
#pragma mark WebView updating

- (NSString*) timeStringSinceNow: (NSDate*) date {
	if (date == nil) return nil;
	
	NSString *result = nil;
	NSTimeInterval timeSince = -[date timeIntervalSinceNow] / 60.0 ; // in minutes
	int value;
	NSString *units;
	if (timeSince <= 1.5) { // report in seconds
		value = floor (timeSince * 60.0);
		units = @"second";
	} else if (timeSince < 90.0) { // report in minutes
		value = floor (timeSince);
		units = @"minute";
	} else if (timeSince < 48.0 * 60.0) { // report in hours
		value = floor (timeSince / 60.0);
		units = @"hour";
	} else { // report in days
		value = floor (timeSince / (24.0 * 60.0));
		units = @"day";
	}
	if (value == 1) {
		result = [NSString stringWithFormat:@"1 %@ ago", units];
	} else {
		result = [NSString stringWithFormat:@"%d %@s ago", value, units];
	}
	return result;
}

- (NSString*) pageTitleHTML {
	TwitterAccount *account = [twitter currentAccount];
	NSString *result;
	if (customPageTitle)
		result =customPageTitle;
	else 
		result = [NSString stringWithFormat:@"<a href='http://mobile.twitter.com/%@'>%@</a>", account.screenName, account.screenName];
	return result;
}

- (NSString*) tabAreaHTML {
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];
	
	int selectedTab = 0;
	if ([selectedTabName isEqualToString: kTimelineIdentifier] || (selectedTabName == nil)) {
		selectedTab = 1;
	} else if ([selectedTabName isEqualToString: kMentionsIdentifier]) {
		selectedTab = 2;
	} else if ([selectedTabName isEqualToString: kDirectMessagesIdentifier]) {
		selectedTab = 3;
	} else if ([selectedTabName isEqualToString: kFavoritesIdentifier]) {
		selectedTab = 4;
	} else {
		selectedTab = 5;
	}
	
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Timeline';\">Timeline</div> ", (selectedTab == 1)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Mentions';\">Mentions</div> ", (selectedTab == 2)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Direct';\">Direct</div> ", (selectedTab == 3)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Favorites';\">Favorites</div> ", (selectedTab == 4)? @"" : @"de"];
	if (selectedTab == 5)
		[html appendFormat:@"<div class='tab selected'>%@</div> ", selectedTabName];
	
	return html;
}

- (NSString*) tweetAreaHTML {
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];
	
	NSArray *timeline = twitter.currentTimeline; 
	
	if ((timeline != nil) && ([timeline count] != 0)) {
		int totalMessages = [timeline count];
		int displayedCount = (totalMessages < kMaxNumberOfMessagesShown) ? totalMessages : kMaxNumberOfMessagesShown;
		
		// Count and oldest
		TwitterMessage *message, *retweeterMessage;
		
		/*
		 if (displayedCount != totalMessages) {
		 [html appendFormat:@"<div class='status time'>%d of %d messages shown", displayedCount, totalMessages];	
		 } else {
		 [html appendFormat:@"<div class='status time'>%d messages", timeline.count];	
		 }
		 message = [timeline lastObject];
		 if (message.createdDate != nil) {
		 [html appendFormat: @" (oldest %@)", [self timeStringSinceNow: message.createdDate]];
		 }
		 [html appendString:@"</div>\n"];
		 */
		
		[html appendString:@"<div class='tweet_table'> "];
		NSAutoreleasePool *pool;
		BOOL isFavorite;
		int index;
		for (index=0; index<displayedCount; index++) {
			pool = [[NSAutoreleasePool alloc] init];
			message = [timeline objectAtIndex:index];
			//isFavorite = message.favorite; // Is the original tweet or the retweeter's tweet supposed to be the one that gets the star? If the latter, uncomment this.
			retweeterMessage = nil;
			NSString *identifier = [message.identifier stringValue];
			
			// Swap retweeted message with root message
			if (message.retweetedMessage != nil) {
				retweeterMessage = message;
				message = retweeterMessage.retweetedMessage;
			}
			
			// Favorites
			isFavorite = (message.favorite || retweeterMessage.favorite);
			
			// Div for each tweet
			[html appendFormat:@"<div class='tweet_row'>", identifier];			
			{
				// Avatar column
				[html appendString:@"<div class='tweet_avatar'>"];
				if (message.avatar != nil) {
					[html appendFormat:@"<img class='avatar_img' id='avatar-%@' src='%@' />", message.identifier, message.avatar];
				}
				[html appendString:@"</div> "]; // Close tweet_avatar.
				
				// Content column including username, text, and other info.
				[html appendString:@"<div class='tweet_content'>"];
				{
					// Screen name
					[html appendString:@"<span class='screen_name'>"];
					if (retweeterMessage != nil)
						[html appendString:@"<img src='retweet.png' /> "]; // Retweet icon.
					if (message.screenName != nil)
						[html appendFormat:@"<a href='http://mobile.twitter.com/%@'>%@</a>", message.screenName, message.screenName];
					[html appendString:@"</span> "]; // Close screen_name
					
					// Lock for protected tweets
					if ([message isLocked])
						[html appendString:@"<img src='lock.png' /> "];
					
					// Content of the tweet
					if (message.content != nil) 
						// Testing:
						//[html appendString:@"[content]"];
						[html appendString: [message layoutSafeContent]];
					
					// Time
					[html appendString:@" <span class='time'><nobr>"];
					[html appendFormat:@"<a href='http://mobile.twitter.com/%@/status/%@'>", message.screenName, [message.identifier stringValue]];
					if (message.createdDate != nil) 
						[html appendString: [self timeStringSinceNow: message.createdDate]];
					[html appendString:@"</a></nobr>"];
					
					// Via 
					if (message.source != nil)
						[html appendFormat:@" via %@", message.source];
					
					// In reply to 
					if ((message.inReplyToScreenName != nil) && (message.inReplyToStatusIdentifier != nil)) {
						[html appendFormat:@" <a href='http://mobile.twitter.com/%@/status/%@'>in reply to %@</a>", message.inReplyToScreenName, [message.inReplyToStatusIdentifier stringValue], message.inReplyToScreenName];
					}
					
					// Retweeted by
					if (retweeterMessage != nil) {
						if (retweeterMessage.screenName != nil) {
							[html appendFormat:@"<span class='time'>. Retweeted by <a href='http://mobile.twitter.com/%@'>%@</a>", retweeterMessage.screenName, retweeterMessage.screenName];
						}
					}
					[html appendString:@"</span> "]; // Close time
				}
				[html appendString:@"</div> "]; // Close tweet_content.
				
				// Actions column
				if (message.direct == NO) { // Can't add direct messages to favorites
					[html appendString:@"<div class='tweet_actions'>"];
					{
						[html appendFormat:@"<a href='action:reply/%@'><img src='action-1.png'></a>", identifier];
						[html appendFormat:@"<a href='action:dm/%@'><img src='action-2.png'></a>", identifier];
						[html appendFormat:@"<a href='action:retweet/%@'><img src='action-3.png'></a>", identifier];
						if (isFavorite) {
							[html appendFormat:@"<a href='action:fave/%@' id='star-%@'><img src='action-4-on.png'></a>", identifier, identifier];
						} else {
							[html appendFormat:@"<a href='action:fave/%@' id='star-%@'><img src='action-4.png'></a>", identifier, identifier];
						}
					}
					[html appendString:@"</div> "]; // Close tweet_actions.
				}
			}
			[html appendString:@"</div> "]; // Close tweet_row.
			[pool release];
		}
		[html appendString:@"</div> "]; // Close tweet_table
		
		/*// Action to Load older messages 
		 if ((displayedCount == totalMessages) && (selectedTab >= 0) && (selectedTab < 3))
		 [html appendString:@"<div class='time' style='text-align:center;'><a href='action:loadOlder'>Load older messages</a></div>\n"];*/
		
	} else { // No tweets
		[html appendString: @"<div class='status'>No messages!</div>"];
	}
	
	return html;
}

- (void) refreshWebView {
	TwitterAccount *account = [twitter currentAccount];
	NSMutableString *html = [[NSMutableString alloc] init];
	// Open html and head tags
	[html appendString:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"];
	[html appendString:@"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">\n"];
	[html appendString:@"<head>\n"];
	[html appendString:@"<meta name='viewport' content='width=device-width' />"];
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[html appendString:@"<link href='style-ipad.css' rel='styleSheet' type='text/css' />"];
	} else {
		[html appendString:@"<link href='style-iphone.css' rel='styleSheet' type='text/css' />"];
	}
	[html appendString:@"<script language='JavaScript' src='functions.js'></script>"];
	
	// Body
	[html appendString:@"</head><body><div class='artboard'>"];
	
	// User name
	if (account.screenName == nil) {
		//[html appendString: @"<div class='login_prompt' onclick=\"location.href='action:login';\">Log In</div>\n"];
		[html appendString:@"<div class='login'>Hi.<br><a href='action:login'>Please log in.</a></div>"];
	} else {
		// The "Loading" spinner
		[html appendString: @"<div id='spinner' class='spinner'>Loading... <img class='spinner_image' src='spinner.gif'></div>"];
		
		// Current account's screen name
		[html appendString:@"<div id='page_title' class='title page_title'>"];
		[html appendString:[self pageTitleHTML]];
		[html appendString:@"</div>\n"];
		
		// Tabs for Timeline, Mentions, Direct Messages
		[html appendString:@"<div id='tab_area' class='tabs'> "];
		[html appendString:[self tabAreaHTML]];
		
		[html appendString:@"</div>\n"]; // Close tabs
		
		// Tweet area
		[html appendString:@"<div id='tweet_area' class='tweet_area'> "];
		//[html appendString: @"<div class='status'><img src='spinner.gif'><br>Loading...</div>"];
		[html appendString: [self tweetAreaHTML]];
		
		// Close tweet area div
		[html appendString:@"</div>\n"];
		
	}
	// Hidden star icons to make sure they're loaded
	[html appendString:@"<div class='hidden_stars'><img src='action-4.png'><img src='action-4-on.png'></div>"];
	
	// Close artboard div, body. and html tags
	[html appendString:@"</div></body></html>\n"];
	
	NSURL *baseURL = [NSURL fileURLWithPath: [[NSBundle mainBundle] bundlePath]];
	[self.webView loadHTMLString:html baseURL:baseURL];
	[html release];
}

- (void) setLoadingSpinnerVisibility: (BOOL) isVisible {
	[self.webView setDocumentElement:@"spinner" visibility:isVisible];
}

- (void) rewriteTabArea {
	[self.webView setDocumentElement:@"tab_area" innerHTML:[self tabAreaHTML]];
}

- (void) rewriteTweetArea {
	// Replace text in tweet area with new statuses
	NSString *result = [self.webView setDocumentElement:@"tweet_area" innerHTML:[self tweetAreaHTML]];
	if ([result length] == 0) { // If the result of the JavaScript call is empty, there was an error.
		NSLog (@"JavaScript error in refreshing tweet area. Reloading entire web view.");
		[self refreshWebView];
		[self setLoadingSpinnerVisibility: NO];
	}
	
	// Start refresh timer so that the timestamps are always accurate
	[refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
}

- (void) fireRefreshTimer:(NSTimer*)timer {
	[self rewriteTweetArea];
}

- (void) replyToMessage: (NSNumber*)identifier {
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithTwitter:twitter] autorelease];
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	
	// Insert @username in beginnig of message. This preserves any other people being replied to.
	if (message != nil) {
		NSString *replyUsername = message.screenName;
		if (compose.messageContent != nil) {
			compose.messageContent = [NSString stringWithFormat:@"@%@ %@", replyUsername, compose.messageContent];
		} else {
			compose.messageContent = [NSString stringWithFormat:@"@%@ ", replyUsername];
		}
	}
	compose.inReplyTo = identifier;
	
	[self closeAllPopovers];
	[self presentContent: compose inNavControllerInPopoverFromItem: composeButton];
}

- (void) directMessageWithTweet:(NSNumber*)identifier {
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithTwitter:twitter] autorelease];
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	
	// Insert d username in beginnig of message. This preserves any other people being replied to.
	if (message != nil) {
		NSString *replyUsername = message.screenName;
		if (compose.messageContent != nil) {
			compose.messageContent = [NSString stringWithFormat:@"d %@ %@", replyUsername, compose.messageContent];
		} else {
			compose.messageContent = [NSString stringWithFormat:@"d %@ ", replyUsername];
		}
	}
	compose.inReplyTo = identifier;
	
	[self closeAllPopovers];
	[self presentContent: compose inNavControllerInPopoverFromItem: composeButton];
}

- (void) showTweet:(NSNumber*)identifier {
	[self showAlertWithTitle:@"Under Construction." message:@"The tweet info feature isn't quite ready."];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
}

#pragma mark -
#pragma mark Twitter timeline selection

- (void) reloadTimeline {
	[self.webView setDocumentElement:@"page_title" innerHTML:[self pageTitleHTML]];
	[self rewriteTabArea];
	[self rewriteTweetArea];
	[self setLoadingSpinnerVisibility: YES];
	[twitter reloadCurrentTimeline];
}

- (void) selectHomeTimeline {
	self.selectedTabName = kTimelineIdentifier;
	[twitter selectHomeTimeline];
	self.customPageTitle = nil; // Reset the custom page title.
}

- (void) selectMentionsTimeline {
	self.selectedTabName = kMentionsIdentifier;
	[twitter selectMentions];
	self.customPageTitle = nil; // Reset the custom page title.
}

- (void) selectDirectMessageTimeline {
	self.selectedTabName = kDirectMessagesIdentifier;
	[twitter selectDirectMessages];
	self.customPageTitle = nil; // Reset the custom page title.
}

- (void) selectFavoritesTimeline {
	self.selectedTabName = kFavoritesIdentifier;
	[twitter selectFavorites];
	self.customPageTitle = nil; // Reset the custom page title.
}

#pragma mark -
#pragma mark Twitter delegate methods

- (void)twitter:(Twitter *)aTwitter didFinishLoadingTimeline:(NSArray *)aTimeline {
	[self rewriteTweetArea];	
	[self setLoadingSpinnerVisibility:NO];
}

- (void)twitter:(Twitter*)aTwitter didSelectTimeline:(NSArray*)aTimeline withName:(NSString*)name tabName:(NSString*)tabName {
	// Switch the web view to display a non-standard timeline
	self.customPageTitle = name;
	self.selectedTabName = tabName;
	
	// Rewrite HTML in web view 
	[self.webView setDocumentElement:@"page_title" innerHTML:[self pageTitleHTML]];
	[self rewriteTabArea];
	[self rewriteTweetArea];	
	[self setLoadingSpinnerVisibility:NO];
	
	// Scroll to top of web view
	[self.webView scrollToTop];
}

- (void)twitter:(Twitter*)aTwitter favoriteDidChange:(TwitterMessage*)aMessage {
	NSString *element = [NSString stringWithFormat:@"star-%@", [aMessage.identifier stringValue]];
	NSString *html = aMessage.favorite ? @"<img src='action-4-on.png'>" : @"<img src='action-4.png'>";
	[self.webView setDocumentElement:element innerHTML:html];
}

- (void) twitterDidRetweet: (Twitter *)aTwitter {
	NSString *title = NSLocalizedString (@"Retweeted!", @"");
	NSString *message = NSLocalizedString (@"You just retweeted that message.", @"");
	[self showAlertWithTitle:title message:message];
}

- (void)twitter:(Twitter*)aTwitter didFailWithNetworkError:(NSError*)anError {
	int statusCode = [anError code];
	NSString *title, *message;
	
	if (statusCode == 401) { // Unauthorized
		title = NSLocalizedString (@"Unable to log in", @"Alert");
		message = NSLocalizedString (@"The Twitter username or password is incorrect. (401 Unauthorized)", @"Alert");
	} else if (statusCode == 403) { // The request is understood, but it has been refused.
		title = NSLocalizedString (@"Request denied.", @"Alert");
		message = NSLocalizedString (@"Duplicate tweet or rate limits reached. (403)", @"Alert");
	} else if (statusCode == 404) { // Not found.
		title = NSLocalizedString (@"Not found.", @"Alert");
		message = NSLocalizedString (@"The requested resource could not be found. (404)", @"Alert");
	} else if (statusCode == 502) { // Twitter is down or being upgraded.
		title = NSLocalizedString (@"Twitter is down!", @"Alert");
		message = NSLocalizedString (@"Twitter is down or being upgraded. (502)", @"Alert");
	} else if (statusCode == 503) { // The Twitter servers are up, but overloaded with requests. Try again later.
		title = NSLocalizedString (@"Too many tweets!", @"Alert");
		message = NSLocalizedString (@"The Twitter servers are overloaded. (503 Service Unavailable)", @"Alert");
	} else {
		title = NSLocalizedString (@"Network error", @"Alert");
		message = [anError localizedDescription];
	}
	
	[self showAlertWithTitle:title message:message];
}

#pragma mark -
#pragma mark UIWebView delegate methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	if ([[url scheme] isEqualToString:@"action"]) {
		//TwitterAccount *account = [twitter currentAccount];
		NSString *actionName = [url resourceSpecifier];
		NSScanner *scanner = [NSScanner scannerWithString:[actionName lastPathComponent]];
		SInt64 identifierInt64;
		[scanner scanLongLong: &identifierInt64];
		NSNumber *messageIdentifier = [NSNumber numberWithLongLong: identifierInt64];
		
		// Tabs
		if ([actionName isEqualToString:kTimelineIdentifier]) { // Home Timeline
			[self selectHomeTimeline];
			[self reloadTimeline];
		} else if ([actionName isEqualToString:kMentionsIdentifier]) { // Mentions
			[self selectMentionsTimeline];
			[self reloadTimeline];
		} else if ([actionName isEqualToString:kDirectMessagesIdentifier]) { // Direct Messages
			[self selectDirectMessageTimeline];
			[self reloadTimeline];
		} else if ([actionName isEqualToString:kFavoritesIdentifier]) { // Favorites
			[self selectFavoritesTimeline];
			[self reloadTimeline];
			
		// Actions
		} else if ([actionName hasPrefix:@"fave"]) { // Add message to favorites or remove from favorites
			[twitter fave: messageIdentifier];
		} else if ([actionName hasPrefix:@"retweet"]) { // Retweet message
			[twitter retweet: messageIdentifier];
		} else if ([actionName hasPrefix:@"reply"]) { // Public reply to the sender
			[self replyToMessage:messageIdentifier];
		} else if ([actionName hasPrefix:@"dm"]) { // Direct message the sender
			[self directMessageWithTweet:messageIdentifier];
		} else if ([actionName hasPrefix:@"info"]) { // Show more info on the tweet
			[self showTweet:messageIdentifier];
		} else if ([actionName hasPrefix:@"login"]) { // Log in
			[self login:accountsButton];
		} else if ([actionName hasPrefix:@"loadOlder"]) { // Load older
			//[self loadOlderMessages:nil];
		}
		
		return NO;
	} else if ([[url scheme] isEqualToString:@"http"]) {
		// Push a separate web browser for links
		WebBrowserViewController *vc = [[WebBrowserViewController alloc] initWithURLRequest:request];
		[self.navigationController pushViewController: vc animated: YES];
		[vc release];
		return NO;
	}
	
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	if (automaticReload) {
		[twitter reloadCurrentTimeline];
		automaticReload = NO;
	}
}

#pragma mark -
#pragma mark Notifications

- (void) currentAccountDidChange: (NSNotification*) aNotification {
	[self closeAllPopovers];
	
	[self selectHomeTimeline];
	[self reloadTimeline];
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewDidLoad {
	[super viewDidLoad];
	[self selectHomeTimeline];	
	[self refreshWebView];
	
	// Automatically reload after web view is done rendering.
	automaticReload = YES;
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setNavigationBarHidden: YES animated: NO];
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	TwitterAccount *currentAccount = [twitter currentAccount];
	if (currentAccount == nil) {
		[self login: accountsButton];
	} else {
		[refreshTimer invalidate];
		refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
	}
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[refreshTimer invalidate];
	refreshTimer = nil;
}

#pragma mark -
#pragma mark IBActions

- (IBAction) login: (id) sender {
	AccountsViewController *accountsController = [self showAccounts: sender];
	[accountsController add: sender];
}

- (IBAction) accounts: (id) sender {
	[self showAccounts: sender];	
}

- (IBAction) lists: (id) sender {
	if ([self closeAllPopovers] == NO) {
		ListsViewController *lists = [[[ListsViewController alloc] initWithTwitter:twitter] autorelease];
		[self presentContent: lists inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction) search: (id) sender {
	if ([self closeAllPopovers] == NO) {
		SearchViewController *search = [[[SearchViewController alloc] initWithTwitter:twitter] autorelease];
		[self presentContent: search inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction) reloadData: (id) sender {
	[twitter reloadCurrentTimeline];
}

- (IBAction) allstars: (id) sender {
	if ([self closeAllPopovers] == NO) {
		TwitterAccount *account = [twitter currentAccount];
		AllStarsViewController *controller = [[[AllStarsViewController alloc] initWithTimeline:account.timeline] autorelease];
		[self presentModalViewController:controller animated:YES];
		[controller startDelayedShuffleModeAfterInterval:kDelayBeforeEnteringShuffleMode];
	}
}

- (IBAction) analyze: (id) sender {
	if ([self closeAllPopovers] == NO) {
		TwitterAccount *account = [twitter currentAccount];
		Analyze *c = [[[Analyze alloc] init] autorelease];
		c.timeline = account.timeline;
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
			c.popover = [self presentPopoverFromItem:sender viewController:c];
		} else {
			[self presentModalViewController:c animated:YES];
		}
	}
}

- (IBAction) compose: (id) sender {
	if ([self closeAllPopovers] == NO) { 
		ComposeViewController *compose = [[[ComposeViewController alloc] initWithTwitter:twitter] autorelease];
		[self presentContent: compose inNavControllerInPopoverFromItem: sender];
	}
}

#pragma mark -
#pragma mark Alert view

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	if (self.currentAlert == nil) { // Dont' another alert if one is already up.
		self.currentAlert = [[[UIAlertView alloc] initWithTitle:aTitle message:aMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[currentAlert show];
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	[self rewriteTweetArea];
	[self setLoadingSpinnerVisibility:NO];
	self.currentAlert = nil;
}

@end

