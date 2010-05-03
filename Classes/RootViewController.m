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

// Constants
#define kMaxNumberOfMessagesInATimeline 600
// When reloading a timeline, newly downloaded messages are merged with existing ones, sorted by identifier, and the oldest ones past this limit are trimmed off.
#define kMaxMessageStaleness (20 * 60) 
// When reloading a timeline, when the newest message in the app is older than this, the app reloads the entire timeline instead of requesting only status updates newer than the newest in the app. This is set to 20 minutes. The number is in seconds.

#import "RootViewController.h"
#import "HelTweeticaAppDelegate.h"
#import "TwitterAccount.h"
#import "TwitterMessage.h"
#import "Analyze.h"
#import "WebBrowserViewController.h"
#import "AccountsViewController.h"
#import "AllStarsViewController.h"
#import "UserPageViewController.h"

#import "TwitterFavoriteAction.h"
#import "TwitterLoginAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"
#import "TwitterSearchAction.h"


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

- (void) reloadWebView;
@end

@implementation RootViewController
@synthesize webView, accountsButton, composeButton, customPageTitle, selectedTabName;
@synthesize twitter, currentAccount, currentTimeline, currentTimelineAction;
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
	
	[twitter release];
	[actions release];
	[currentAccount release];
	[currentTimeline release];
	[currentTimelineAction release];
	[defaultCount release];
	
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
	
	// String to pass in the count, per_page, and rpp parameters.
	defaultCount = [@"100" retain];
	
	actions = [[NSMutableArray alloc] init];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(currentAccountDidChange:) name:@"currentAccountDidChange" object:nil];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//selectedTab = [defaults integerForKey:@"selectedTab"];
	
	NSString *currentAccountScreenName = [defaults objectForKey: @"currentAccount"];
	if (currentAccountScreenName) {
		self.currentAccount = [twitter accountWithScreenName:currentAccountScreenName];
	} else {
		if (twitter.accounts.count > 0) 
			self.currentAccount = [twitter.accounts objectAtIndex: 0];
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

- (NSString*) currentAccountHTML {
	return [NSString stringWithFormat:@"<a href='action:user/%@'>%@</a>", currentAccount.screenName, currentAccount.screenName];
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
	
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Timeline';\">Timeline</div>", (selectedTab == 1)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Mentions';\">Mentions</div>", (selectedTab == 2)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Direct';\">Direct</div>", (selectedTab == 3)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Favorites';\">Favorites</div>", (selectedTab == 4)? @"" : @"de"];
	if (selectedTab == 5)
		[html appendFormat:@"<div class='tab selected'>%@</div>", selectedTabName];
	
	return html;
}

- (NSString*) tweetAreaHTML {
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];
	
	NSArray *timeline = currentTimeline; 
	
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

		// Page title for Lists and Search
		if (customPageTitle) {
			// Put the title inside a regular tweet table row.
			[html appendString:@"<div class='tweet_row'><div class='tweet_avatar'></div><div class='tweet_content'>"];
			[html appendFormat:@"<div class='page_title'>%@</div>", customPageTitle];
			[html appendString:@"</div><div class='tweet_actions'> </div></div>"];
		}
		
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
						[html appendFormat:@"<a href='action:user/%@'>%@</a>", message.screenName, message.screenName];
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
					[html appendFormat:@"<a href='action:conversation/%@'>", [message.identifier stringValue]]; 
					if (message.createdDate != nil) 
						[html appendString: [self timeStringSinceNow: message.createdDate]];
					[html appendString:@"</a></nobr>"];
					
					// Via 
					if (message.source != nil)
						[html appendFormat:@" via %@", message.source];
					
					// In reply to 
					if ((message.inReplyToScreenName != nil) && (message.inReplyToStatusIdentifier != nil)) {
						[html appendFormat:@" <a href='action:conversation/%@'>in reply to %@</a>", [message.identifier stringValue], message.inReplyToScreenName]; 
					} 
					
					// Retweeted by
					if (retweeterMessage != nil) {
						if (retweeterMessage.screenName != nil) {
							[html appendFormat:@"<span class='time'>. Retweeted by <a href='action:user/%@'>%@</a>", retweeterMessage.screenName, retweeterMessage.screenName];
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
		
	} else { // No tweets or Loading
		if (actions.count > 0)
			[html appendString: @"<div class='status'>Loading...</div>"];
		else
			[html appendString: @"<div class='status'>No messages.</div>"];
	}
	
	return html;
}

- (void) reloadWebView {
	TwitterAccount *account = self.currentAccount;
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSURL *baseURL = [NSURL fileURLWithPath:mainBundle];
	NSError *error = nil;
	
	// Header
	NSString *headerHTML = [NSString stringWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"header.html"] encoding:NSUTF8StringEncoding error:&error];
	if (error != nil) {
		NSLog (@"Error loading header.html: %@", [error localizedDescription]);
	}
	NSMutableString *html = [[NSMutableString alloc] initWithString:headerHTML];

	// Artboard div with padding for transparent toolbar
	[html appendString:@"<div class='artboard toolbar_padding'>"];
	
	// User name
	if (account.screenName == nil) {
		//[html appendString: @"<div class='login_prompt' onclick=\"location.href='action:login';\">Log In</div>\n"];
		[html appendString:@"<div class='login'>Hi.<br><a href='action:login'>Please log in.</a></div>"];
	} else {
		// The "Loading" spinner
		[html appendString: @"<div id='spinner' class='spinner'>Loading... <img class='spinner_image' src='spinner.gif'></div>"];
		
		// Current account's screen name
		[html appendString:@"<div id='current_account' class='title current_account'>"];
		[html appendString:[self currentAccountHTML]];
		[html appendString:@"</div>\n"];
		
		// Tabs for Timeline, Mentions, Direct Messages
		[html appendString:@"<div id='tab_area' class='tabs'> "];
		[html appendString:[self tabAreaHTML]];
		[html appendString:@"</div>\n"]; // Close tabs
		
		// Tweet area
		[html appendString:@"<div id='tweet_area' class='tweet_area'> "];
		[html appendString: [self tweetAreaHTML]];
		[html appendString:@"</div>\n"];
		
	}
	
	// Footer
	error = nil;
	NSString *footerHTML = [NSString stringWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"footer.html"] encoding:NSUTF8StringEncoding error:&error];
	if (error != nil) {
		NSLog (@"Error loading footer.html: %@", [error localizedDescription]);
	}
	[html appendString:footerHTML];
	
	[self.webView loadHTMLString:html baseURL:baseURL];
	[html release];
}

#pragma mark HTML rewriting

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
		[self reloadWebView];
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

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// TODO: show conversation page
	[self showAlertWithTitle:@"Under Construction." message:@"The tweet info feature isn't quite ready."];
}

#pragma mark Pushing view controllers

- (void) showUserPage:(NSString*)screenName {
	// Use a custom timeline showing the user's tweets, but with a big header showing the user's info.
	TwitterUser *user = [twitter userWithScreenName:screenName];
	if (user == nil) {
		// Create an empty user and add it to the Twitter set
		user = [[[TwitterUser alloc] init] autorelease];
		user.screenName = screenName;
		user.identifier = [NSNumber numberWithInt: -1]; // -1 signifies that user info has not been loaded
	}
	
	// Show user page
	UserPageViewController *vc = [[[UserPageViewController alloc] initWithTwitter:twitter user:user] autorelease];
	[self.navigationController pushViewController: vc animated: YES];
}

- (void) showWebBrowserWithURLRequest:(NSURLRequest*)request {
	// Push a separate web browser for links
	WebBrowserViewController *vc = [[[WebBrowserViewController alloc] initWithURLRequest:request] autorelease];
	[self.navigationController pushViewController: vc animated: YES];
}	

#pragma mark -
#pragma mark TwitterAction

- (void) startTwitterAction:(TwitterAction*)action withToken:(BOOL)useToken {
	// Add the action to the array of actions, and updates the network activity spinner
	[actions addObject: action];
	
	// Set up Twitter action
	action.delegate = self;
	if (useToken) {
		action.consumerToken = currentAccount.xAuthToken;
		action.consumerSecret = currentAccount.xAuthSecret;
	}
	
	// Start the URL connection
	[action start];
	
	// Show the Loading spinner
	
}

- (void) removeTwitterAction:(TwitterAction*)action {
	// Removes the action from the array of actions, and updates the network activity spinner
	[actions removeObject: action];
}

#pragma mark TwitterAction delegate methods

- (void) showNetworkErrorAlertForStatusCode:(int)statusCode {
	// Show alert with error code and message.
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
		message = [NSString localizedStringWithFormat:@"Something went wrong with the network. (%d)", statusCode];
	}
	
	[self showAlertWithTitle:title message:message];
}

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	[self removeTwitterAction:action];
	
	// Deal with status codes 400 to 402 and 404 and up.
	if ((action.statusCode >= 400) && (action.statusCode != 403)) {
		[self showNetworkErrorAlertForStatusCode:action.statusCode];
	}
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	[actions removeObject: action];
	
	NSString *title = NSLocalizedString (@"Network error", @"Alert");
	[self showAlertWithTitle:title message:[error localizedDescription]];

}

#pragma mark TwitterAction - Timeline

// TODO: add own RTs to home timeline
// See http://apiwiki.twitter.com/Twitter-REST-API-Method%3A-statuses-retweeted_by_me

- (void)reloadCurrentTimeline {
	// Set the since_id parameter if there already are messages in the current timeline
	NSNumber *newerThan = nil;
	if ([currentTimeline count] > 10) {
		TwitterMessage *message = [currentTimeline objectAtIndex: 0];
		NSTimeInterval staleness = -[message.receivedDate timeIntervalSinceNow];
		if (staleness < kMaxMessageStaleness) {
			newerThan = message.identifier;
		}
	}
	
	TwitterAction *action = self.currentTimelineAction;
	if (newerThan)
		[action.parameters setObject:[newerThan stringValue] forKey:@"since_id"];
	
	// Prepare action and start it. 
	action.completionTarget= self;
	action.completionAction = @selector(didReloadCurrentTimeline:);
	[self startTwitterAction:action withToken:YES];
}

- (void)didReloadCurrentTimeline:(TwitterLoadTimelineAction *)action {
	if (action.messages.count > 0) {
		NSMutableArray *newMessages = [NSMutableArray arrayWithArray: action.messages];
		
		// Search results will not have valid favorite flag data because it's not linked to an account.
		BOOL updateFaves = ([action isKindOfClass:[TwitterSearchAction class]] == NO); 
		[twitter synchronizeStatusesWithArray: newMessages updateFavorites:updateFaves];
		
		// Merge downloaded messages with existing messages.
		for (TwitterMessage *message in newMessages) {
			if ([currentTimeline containsObject:message] == NO)
				[currentTimeline addObject: message];
		}
		
		// Update set of users.
		NSSet *newUsers = action.users;
		TwitterUser *member;
		for (TwitterUser *user in newUsers) {
			member = [twitter.users member:user];
			if (member) {
				[twitter.users removeObject:member];
			}
			[twitter.users addObject: user];
		}
		
		// Sort by identifier, descending.
		NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
		[currentTimeline sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
		
		// Keep timeline within size limits by removing old messages.
		if (currentTimeline.count > kMaxNumberOfMessagesInATimeline) {
			NSRange removalRange = NSMakeRange(kMaxNumberOfMessagesInATimeline, currentTimeline.count - kMaxNumberOfMessagesInATimeline);
			[currentTimeline removeObjectsInRange:removalRange];
		}
	}
	
	// Finished loading, so update tweet area and remove loading spinner.
	[self rewriteTweetArea];	
	[self setLoadingSpinnerVisibility:NO];
}

#pragma mark Twitter timeline selection

- (void) startLoadingCurrentTimeline {
	[self reloadCurrentTimeline];
	[self rewriteTabArea];
	[self rewriteTweetArea];
	[self setLoadingSpinnerVisibility: YES];
}

- (void) selectHomeTimeline {
	self.selectedTabName = kTimelineIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.

	self.currentTimeline = currentAccount.timeline;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/home_timeline"] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"count"];
}

- (void) selectMentionsTimeline {
	self.selectedTabName = kMentionsIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.

	self.currentTimeline = currentAccount.mentions;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/mentions"] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"count"];
}

- (void) selectDirectMessageTimeline {
	self.selectedTabName = kDirectMessagesIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.

	self.currentTimeline = currentAccount.directMessages;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"direct_messages"] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"count"];
}

- (void) selectFavoritesTimeline {
	self.selectedTabName = kFavoritesIdentifier;
	self.customPageTitle = nil; // Reset the custom page title.

	self.currentTimeline = currentAccount.favorites;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	// Favorites always loads 20 per page. Cannot change the count.
}

#pragma mark Twitter delegate methods

- (void)twitter:(Twitter*)aTwitter willLoadTimelineWithName:(NSString*)name tabName:(NSString*)tabName {
	// Switch the web view to display a non-standard timeline
	self.customPageTitle = name;
	self.selectedTabName = tabName;
	
	// Rewrite HTML in web view 
	[self rewriteTabArea];
	[self rewriteTweetArea];	
	[self setLoadingSpinnerVisibility:YES];
	
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
	// Remove any Loading messages.
	[self rewriteTweetArea];	
	[self setLoadingSpinnerVisibility:NO];

}

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
			[self startLoadingCurrentTimeline];
		} else if ([actionName isEqualToString:kMentionsIdentifier]) { // Mentions
			[self selectMentionsTimeline];
			[self startLoadingCurrentTimeline];
		} else if ([actionName isEqualToString:kDirectMessagesIdentifier]) { // Direct Messages
			[self selectDirectMessageTimeline];
			[self startLoadingCurrentTimeline];
		} else if ([actionName isEqualToString:kFavoritesIdentifier]) { // Favorites
			[self selectFavoritesTimeline];
			[self startLoadingCurrentTimeline];
			
		// Actions
		} else if ([actionName hasPrefix:@"fave"]) { // Add message to favorites or remove from favorites
			[twitter fave: messageIdentifier];
		} else if ([actionName hasPrefix:@"retweet"]) { // Retweet message
			[twitter retweet: messageIdentifier];
		} else if ([actionName hasPrefix:@"reply"]) { // Public reply to the sender
			[self replyToMessage:messageIdentifier];
		} else if ([actionName hasPrefix:@"dm"]) { // Direct message the sender
			[self directMessageWithTweet:messageIdentifier];
		} else if ([actionName hasPrefix:@"login"]) { // Log in
			[self login:accountsButton];
		} else if ([actionName hasPrefix:@"user"]) { // Show user page
			[self showUserPage:[actionName lastPathComponent]];
		} else if ([actionName hasPrefix:@"conversation"]) { // Show more info on the tweet
			[self showConversationWithMessageIdentifier:messageIdentifier];
		} else if ([actionName hasPrefix:@"loadOlder"]) { // Load older
			//[self loadOlderMessages:nil];
		}
		
		return NO;
	} else if ([[url scheme] hasPrefix:@"http"]) {
		// Push a separate web browser for links
		[self showWebBrowserWithURLRequest:request];
		return NO;
	}
	
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	if (automaticReload) {
		[self reloadCurrentTimeline];
		automaticReload = NO;
	}
}

#pragma mark Popover delegate methods

- (void) sendStatusUpdate:(NSString*)text inReplyTo:(NSNumber*)inReplyTo {
	[twitter updateStatus:text inReplyTo:inReplyTo];
}

- (void) lists:(ListsViewController*)lists didSelectList:(TwitterList*)list {
	self.currentTimeline = list.statuses;
	
	// Style the page title
	NSString *pageTitle = list.fullName;
	NSArray *nameParts = [list.fullName componentsSeparatedByString:@"/"];
	if (nameParts.count == 2) {
		pageTitle = [NSString stringWithFormat:@"%@/<b>%@</b>", [nameParts objectAtIndex:0], [nameParts objectAtIndex:1]];
	}
	self.customPageTitle = pageTitle;
	
	// Create Twitter action to load list statuses into the timeline.
	NSString *method = [NSString stringWithFormat:@"%@/lists/%@/statuses", list.username, list.identifier];
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:method] autorelease];
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"per_page"];
	[self reloadCurrentTimeline];
	
	// TODO: rewrite HTML and show loading spinner?
	// Do everything in willLoadTimelineWithName — test to see what needs to be done.
}

- (NSString *)htmlSafeString:(NSString *)string {
	NSMutableString *result = [NSMutableString stringWithString:string];
	[result replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (void) search:(SearchViewController*)search didRequestQuery:(NSString*)query {
	self.currentTimeline = [NSMutableArray array]; // Always start with an empty array of messages for Search.
	self.customPageTitle = [NSString stringWithFormat: @"Search for &ldquo;<b>%@</b>&rdquo;", [self htmlSafeString:query]];
	
	// Create Twitter action to load search results into the current timeline.
	TwitterSearchAction *action = [[[TwitterSearchAction alloc] initWithQuery:query count:defaultCount] autorelease];
	self.currentTimelineAction = action;
	[self reloadCurrentTimeline];
	
	// TODO: rewrite HTML and show loading spinner?
	// Do everything in willLoadTimelineWithName — test to see what needs to be done.
}

#pragma mark -
#pragma mark Notifications

- (void) currentAccountDidChange: (NSNotification*) aNotification {
	[self closeAllPopovers];
	
	[self.webView setDocumentElement:@"current_account" innerHTML:[self currentAccountHTML]];
	
	[self selectHomeTimeline];
	[self startLoadingCurrentTimeline];
}

// TODO: Remove this notification
// Also need to save account when user switches it.
// [defaults setObject: self.currentAccount.screenName forKey: @"currentAccount"];


#pragma mark -
#pragma mark View lifecycle

- (void) viewDidLoad {
	[super viewDidLoad];
	[self selectHomeTimeline];	
	[self reloadWebView];
	
	// Automatically reload after web view is done rendering.
	automaticReload = YES;
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
		ListsViewController *lists = [[[ListsViewController alloc] initWithAccount:currentAccount] autorelease];
		[self presentContent: lists inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction) search: (id) sender {
	if ([self closeAllPopovers] == NO) {
		SearchViewController *search = [[[SearchViewController alloc] initWithAccount:currentAccount] autorelease];
		[self presentContent: search inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction) reloadData: (id) sender {
	[self setLoadingSpinnerVisibility:YES];
	[self reloadCurrentTimeline];
}

- (IBAction) allstars: (id) sender {
	if ([self closeAllPopovers] == NO) {
		AllStarsViewController *controller = [[[AllStarsViewController alloc] initWithTimeline:currentAccount.timeline] autorelease];
		[self presentModalViewController:controller animated:YES];
		[controller startDelayedShuffleModeAfterInterval:kDelayBeforeEnteringShuffleMode];
	}
}

- (IBAction) analyze: (id) sender {
	if ([self closeAllPopovers] == NO) {
		Analyze *c = [[[Analyze alloc] init] autorelease];
		c.timeline = currentAccount.timeline;
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

