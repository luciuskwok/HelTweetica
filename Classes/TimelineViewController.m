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

// Constants
#define kDefaultMaxTweetsShown 200

// Imports
#import "TimelineViewController.h"
#import "LKWebView.h"
#import "HelTweeticaAppDelegate.h"

#import "ConversationViewController.h"
#import "UserPageViewController.h"
#import "WebBrowserViewController.h"
#import "SearchResultsViewController.h"

#import "TwitterFavoriteAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"



@implementation TimelineViewController
@synthesize webView, composeButton, twitter, actions, defaultLoadCount;
@synthesize currentAccount, currentTimeline, currentTimelineAction, customPageTitle, customTabName;
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
	
	self.defaultLoadCount = @"50"; // String to pass in the count, per_page, and rpp parameters.
	maxTweetsShown = kDefaultMaxTweetsShown; // Number of tweet_rows to display in web view
	
	self.actions = [NSMutableArray array]; // List of currently active network connections
	networkIsReachable = YES;
	
	// Keep the HTML templates around
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSError *error = nil;
	tweetRowTemplate = [[NSString alloc] initWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"tweet-row-template.html"] encoding:NSUTF8StringEncoding error:&error];
	if (error != nil)
		NSLog (@"Error loading tweet-row-template.html: %@", [error localizedDescription]);
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
	self.webView = nil;
	self.composeButton = nil;
}

- (void)dealloc {
	[webView release];
	[composeButton release];
	
	[twitter release];
	[actions release];
	[defaultLoadCount release];
 
	[currentAccount release];
	[currentTimeline release];
	[currentTimelineAction release];
	[customPageTitle release];
	[customTabName release];
	
	currentPopover.delegate = nil;
	[currentPopover release];
	currentActionSheet.delegate = nil;
	[currentActionSheet release];
	currentAlert.delegate = nil;
	[currentAlert release];

	[tweetRowTemplate release];
	
	[super dealloc];
}

#pragma mark View lifecycle

- (void) viewDidLoad {
	[super viewDidLoad];
	[self reloadWebView];
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[refreshTimer invalidate];
	refreshTimer = nil;
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
		SearchViewController *search = [[[SearchViewController alloc] initWithAccount:currentAccount] autorelease];
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
	suppressNetworkErrorAlerts = NO;
	[self reloadCurrentTimeline];
	[self.webView scrollToTop];
}

#pragma mark TwitterAction

- (void)startTwitterAction:(TwitterAction*)action {
	// Add the action to the array of actions, and updates the network activity spinner
	[actions addObject: action];
	
	// Set up Twitter action
	action.delegate = self;
	action.consumerToken = currentAccount.xAuthToken;
	action.consumerSecret = currentAccount.xAuthSecret;
	
	// Start the URL connection
	[action start];
	
	// Show the Loading spinner
	[self setLoadingSpinnerVisibility:YES];
	
}

- (void) removeTwitterAction:(TwitterAction*)action {
	// Removes the action from the array of actions, and updates the network activity spinner
	[actions removeObject: action];
	
	if (actions.count == 0) {
		[self rewriteTweetArea]; // Remove any Loading messages.
		[self setLoadingSpinnerVisibility:NO];
	}
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

- (void)handleTwitterStatusCode:(int)code {
	if ((code >= 400) && (code != 403)) {
		[self showNetworkErrorAlertForStatusCode:code];
	}
}

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	// Deal with status codes 400 to 402 and 404 and up.
	[self handleTwitterStatusCode:action.statusCode];
	[self removeTwitterAction:action];
	networkIsReachable = YES;
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	NSString *title = NSLocalizedString (@"Network error", @"Alert");
	[self showAlertWithTitle:title message:[error localizedDescription]];
	[self removeTwitterAction: action];
	networkIsReachable = NO;
}


#pragma mark TwitterAction - Timeline

// TODO: need to fold in own RTs to home timeline
// See http://apiwiki.twitter.com/Twitter-REST-API-Method%3A-statuses-retweeted_by_me

- (void)reloadCurrentTimeline {
	if (currentAccount == nil || currentAccount.xAuthToken == nil) {
		[self setLoadingSpinnerVisibility:NO];
		return; // No current account or not logged in.
	}
	
	TwitterLoadTimelineAction *action = self.currentTimelineAction;
	if (action == nil) return; // No action to reload.

	BOOL isFavorites = [action.twitterMethod isEqualToString:@"favorites"];
	
	// Set the since_id parameter if there already are messages in the current timeline, except for the favorites timeline, because older tweets can be faved.
	NSNumber *newerThan = nil;
	if (([currentTimeline count] > 2) && (isFavorites == NO)) {
		TwitterMessage *message = [currentTimeline objectAtIndex: 1]; // Use object at index 1, and test for overlap to determine whether there is a gap in the timeline.
		NSTimeInterval staleness = -[message.receivedDate timeIntervalSinceNow];
		if (staleness < kMaxMessageStaleness) {
			newerThan = message.identifier;
		}
	}
	
	if (newerThan)
		[action.parameters setObject:[newerThan stringValue] forKey:@"since_id"];
	
	// Remove "max_id" parameter in case it was set from loading older messages;
	[action.parameters removeObjectForKey:@"max_id"];
	
	// Prepare action and start it. 
	action.timeline = currentTimeline;
	action.completionTarget= self;
	action.completionAction = @selector(didReloadCurrentTimeline:);
	[self startTwitterAction:action];
}

- (void)didReloadCurrentTimeline:(TwitterLoadTimelineAction *)action {
	// Synchronize timeline with Twitter cache.
	[twitter synchronizeStatusesWithArray:action.timeline updateFavorites:YES];
	[twitter addUsers:action.users];
	
	// Limit the length of the timeline
	if (action.timeline.count > kMaxNumberOfMessagesInATimeline) {
		NSRange removalRange = NSMakeRange(kMaxNumberOfMessagesInATimeline, action.timeline.count - kMaxNumberOfMessagesInATimeline);
		[action.timeline removeObjectsInRange:removalRange];
	}
	
	// Finished loading, so update tweet area and remove loading spinner.
	[self rewriteTweetArea];	

	// Also start an action to load RTs that the account's user has posted within the loaded timeline
	if (action.loadedMessages.count > 1) {
		TwitterMessage *firstMessage = [action.loadedMessages objectAtIndex:0];
		TwitterMessage *lastMessage = [action.loadedMessages lastObject];
		NSNumber *sinceIdentifier = lastMessage.identifier;
		NSNumber *maxIdentifier = firstMessage.identifier;
		
		[self reloadRetweetsSince:sinceIdentifier toMax:maxIdentifier];
	}
}

- (void)reloadRetweetsSince:(NSNumber*)sinceIdentifier toMax:(NSNumber*)maxIdentifier {
	// Subclasses should implement this method to load the correct RT timeline.
	// This method loads RTs that are newer than the since_id and up to and incuding the max_id.
}

- (void)loadOlderInCurrentTimeline {
	if (currentAccount == nil || currentAccount.xAuthToken == nil) {
		return; // No current account or not logged in.
	}
	
	TwitterLoadTimelineAction *action = self.currentTimelineAction;
	if (action == nil) return; // No action to reload.
	
	// Issue: if the display only shows 200 tweets, the "Show Older" link should just show a page starting from the next items in the array. And if there are gaps in the timeline, there's no easy way of showing them.
	
	NSNumber *olderThan = nil;
	if ([currentTimeline count] > 2) {
		TwitterMessage *message = [currentTimeline lastObject];
		olderThan = message.identifier;
	}
	
	if (olderThan)
		[action.parameters setObject:[olderThan stringValue] forKey:@"max_id"];
	
	// Remove "since_id" parameter in case it was set from loading newer messages;
	[action.parameters removeObjectForKey:@"since_id"];
	
	// Prepare action and start it. 
	action.timeline = currentTimeline;
	action.completionTarget= self;
	action.completionAction = @selector(didLoadOlderInCurrentTimeline:);
	[self startTwitterAction:action];
	
	// Show Loading message.
	[self rewriteTweetArea];
}

- (void) didLoadOlderInCurrentTimeline:(TwitterLoadTimelineAction *)action {
	if (action.newMessageCount > 0) {
		// Synchronize timeline with Twitter cache.
		[twitter synchronizeStatusesWithArray:action.timeline updateFavorites:YES];
		[twitter addUsers:action.users];
	}
	
	if (action.newMessageCount <= 2) { // The one message is the one in the max_id.
		noOlderMessages = YES;
	}
	
	// Finished loading, so update tweet area and remove loading spinner.
	[self rewriteTweetArea];
		
}


- (void) startLoadingCurrentTimeline {
	suppressNetworkErrorAlerts = NO;
	if (networkIsReachable) {
		[self reloadCurrentTimeline];
	}
	[self rewriteTweetArea];
}

- (void) fireRefreshTimer:(NSTimer*)timer {
	// Clear pointer to timer because this is a non-recurring timer.
	[refreshTimer invalidate];
	refreshTimer = nil;
	
	// If there are actions already pending, reschedule refresh 
	if ([actions count] == 0 && webViewHasValidHTML) {
		CGPoint scrollPosition = [self.webView scrollPosition];
		if (scrollPosition.y == 0.0f && networkIsReachable && !currentPopover&& !currentAlert && !currentActionSheet) {
			// Only reload from the network if the scroll position is at the top, the web view has been loaded, the network is reachable, and no popovers are showing.
			suppressNetworkErrorAlerts = YES; // Don't show an error alert for auto reloads.
			[self reloadCurrentTimeline];
		} else {
			// Don't load new statuses if scroll position is below top.
			[self rewriteTweetArea];
		}
	} else {
		refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
	}
}


#pragma mark TwitterAction - Misc

- (void) updateStatus:(NSString*)text inReplyTo:(NSNumber*)messageIdentifier {
	TwitterUpdateStatusAction *action = [[[TwitterUpdateStatusAction alloc] initWithText:text inReplyTo:messageIdentifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didUpdateStatus:);
	[self startTwitterAction:action];
}

- (void)didUpdateStatusSuccessfully {
	// Remove message text from compose screen.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:@"" forKey:@"messageContent"];
	[defaults removeObjectForKey:@"inReplyTo"];
	
	// Reload timeline
	[self startLoadingCurrentTimeline];
}

- (void)didUpdateStatus:(TwitterUpdateStatusAction *)action {
	if ((action.statusCode < 400) || (action.statusCode == 403)) { // Twitter returns 403 if user tries to post duplicate status updates.
		[self didUpdateStatusSuccessfully];
	} else {
		// Status update was not successful, so report the error.
		[self showNetworkErrorAlertForStatusCode:action.statusCode];
	}
}

- (void)didRetweet:(id)action {
	[self didUpdateStatusSuccessfully];
}

- (void) fave: (NSNumber*) messageIdentifier {
	TwitterMessage *message = [twitter statusWithIdentifier: messageIdentifier];
	if (message == nil) {
		NSLog (@"Cannot find the message to fave (or unfave). id == %@", messageIdentifier);
		return;
	}
	
	TwitterFavoriteAction *action = [[[TwitterFavoriteAction alloc] initWithMessage:message destroy:message.favorite] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didFave:);
	[self startTwitterAction:action];
}

- (void)didFave:(TwitterFavoriteAction *)action {
	TwitterMessage *message = [action message];
	
	// Change the display of the star next to tweet in root view
	NSString *element = [NSString stringWithFormat:@"star-%@", [message.identifier stringValue]];
	NSString *html = message.favorite ? @"<img src='action-4-on.png'>" : @"<img src='action-4.png'>";
	[self.webView setDocumentElement:element innerHTML:html];
	
	// Remove from favorites timeline
	[currentAccount.favorites removeObject: message];
}

#pragma mark Compose

- (IBAction)compose:(id)sender {
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:currentAccount] autorelease];
	[compose loadFromUserDefaults];
	compose.delegate = self;
	[self presentContent: compose inNavControllerInPopoverFromItem: sender];
}	

- (void)retweet:(NSNumber*)identifier {
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	if (message == nil) return;
	
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:currentAccount] autorelease];
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
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:currentAccount] autorelease];
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
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:currentAccount] autorelease];
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
		
		/* The only reason that the content view controller has a reference to the popover is so that it can close it. 
			An alternative is to have the delegate methods include one to close the popover.
			Chockenberry's solution is to have a global variable or singleton which manages the popover.
		*/
		
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
	vc.currentAccount = self.currentAccount;
	[self.navigationController pushViewController: vc animated: YES];
}

- (void) searchForQuery:(NSString*)query {
	[self closeAllPopovers];
	SearchResultsViewController *vc = [[[SearchResultsViewController alloc] initWithQuery:query] autorelease];
	vc.currentAccount = self.currentAccount;
	[self.navigationController pushViewController: vc animated: YES];
}	

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// Show conversation page
	ConversationViewController *vc = [[[ConversationViewController alloc] initWithMessageIdentifier:identifier] autorelease];
	vc.currentAccount = self.currentAccount;
	[self.navigationController pushViewController: vc animated: YES];
}

- (void) showWebBrowserWithURLRequest:(NSURLRequest*)request {
	// Push a separate web browser for links
	WebBrowserViewController *vc = [[[WebBrowserViewController alloc] initWithURLRequest:request] autorelease];
	[self.navigationController pushViewController: vc animated: YES];
}	


#pragma mark UIWebView updating

- (void) reloadWebView {
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSURL *baseURL = [NSURL fileURLWithPath:mainBundle];
	
	// Load template and replace special tags with data
	NSString *template = [self webPageTemplate];
	if (template == nil) return;
	NSMutableString *html = [NSMutableString stringWithString:template];
	
	NSString *tweetAreaHTML = @"";
	
	if (currentAccount.screenName == nil) {
		tweetAreaHTML = @"<div class='login'>Hi.<br><a href='action:login'>Please log in.</a></div>";
	} else {
		tweetAreaHTML = [self tweetAreaHTML];
	}
	
	// Replace custom tags with HTML
	[html replaceOccurrencesOfString:@"<tweetAreaHTML/>" withString:tweetAreaHTML options:0 range:NSMakeRange(0, html.length)];
	
	[self.webView loadHTMLString:html baseURL:baseURL];
}

- (void) setLoadingSpinnerVisibility: (BOOL) isVisible {
	if (webViewHasValidHTML)
		[self.webView setDocumentElement:@"spinner" visibility:isVisible];
}

- (void) rewriteTweetArea {
	// Replace text in tweet area with new statuses
	if (webViewHasValidHTML) {
		NSString *result = [self.webView setDocumentElement:@"tweet_area" innerHTML:[self tweetAreaHTML]];
		if ([result length] == 0) { // If the result of the JavaScript call is empty, there was an error.
			NSLog (@"JavaScript error in refreshing tweet area. Reloading entire web view.");
			[self reloadWebView];
		}
	}
	
	// Start refresh timer so that the timestamps are always accurate
	[refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
}

- (NSString*) webPageTemplate {
	return nil;
}

- (NSString*) tweetAreaHTML {
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];
	
	[html appendString:@"<div class='tweet_table'> "];
	
	// Page Title for Lists and Search
	if (customPageTitle) {
		// Put the title inside a regular tweet table row.
		[html appendString:@"<div class='tweet_row'><div class='tweet_avatar'></div><div class='tweet_content'>"];
		[html appendFormat:@"<div class='page_title'>%@</div>", customPageTitle];
		[html appendString:@"</div><div class='tweet_actions'> </div></div>"];
	}
	
	NSArray *timeline = self.currentTimeline; 
	int displayedCount = (timeline.count < maxTweetsShown) ? timeline.count : maxTweetsShown;
	
	// Template for tweet_row
	
	NSAutoreleasePool *pool;
	for (int index=0; index<displayedCount; index++) {
		pool = [[NSAutoreleasePool alloc] init];
		[html appendString: [self tweetRowHTMLForRow:index]];
		[pool release];
	}
		
	[html appendString:@"</div> "]; // Close tweet_table
	
	// Footer
	[html appendString:[self tweetAreaFooterHTML]];
	
	return html;
}

- (NSString *)tweetRowTemplateForRow:(int)row {
	return tweetRowTemplate;
}

- (NSString *)tweetRowHTMLForRow:(int)row {
	NSMutableString *tweetRowHTML;
	TwitterMessage *message = [self.currentTimeline objectAtIndex:row];
	TwitterMessage *retweeterMessage = nil;
	
	// Swap retweeted message with root message
	if (message.retweetedMessage != nil) {
		retweeterMessage = message;
		message = retweeterMessage.retweetedMessage;
	}
	
	// Favorites
	BOOL isFavorite = (message.favorite || retweeterMessage.favorite);
	
	// Create mutable copy of template
	tweetRowHTML = [NSMutableString stringWithString: [self tweetRowTemplateForRow: row]];
	
	// Fields for replacement
	NSString *screenName = message.screenName ? message.screenName : @"";
	NSString *messageIdentifier = message.identifier ? [message.identifier stringValue] : @"";
	NSString *profileImageURL = message.avatar ? message.avatar : @"";
	NSString *retweetIcon = retweeterMessage ? @"<img src='retweet.png'>" : @"";
	NSString *lockIcon = [message isLocked] ? @"<img src='lock.png'>" : @"";
	NSString *content = message.content ? [self htmlFormattedString:message.content] : @"";
	NSString *createdDate = message.createdDate ? [self timeStringSinceNow: message.createdDate] : @"";
	NSString *via = message.source ? message.source : @"";
	NSString *inReplyToScreenName = message.inReplyToScreenName ? message.inReplyToScreenName : @"";
	NSString *retweetedBy = retweeterMessage.screenName ? retweeterMessage.screenName : @"";
	NSString *faveImageSuffix = isFavorite ? @"-on" : @"";
	
	// Replace fields in template with actual data
	[tweetRowHTML replaceOccurrencesOfString:@"{screenName}" withString:screenName options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{messageIdentifier}" withString:messageIdentifier options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{profileImageURL}" withString:profileImageURL options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{retweetIcon}" withString:retweetIcon options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{lockIcon}" withString:lockIcon options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{content}" withString:content options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{createdDate}" withString:createdDate options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{via}" withString:via options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{inReplyToScreenName}" withString:inReplyToScreenName options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{retweetedBy}" withString:retweetedBy options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	[tweetRowHTML replaceOccurrencesOfString:@"{faveImageSuffix}" withString:faveImageSuffix options:0 range:NSMakeRange(0, tweetRowHTML.length)];
	
	// Replace blocks in template
	[self replaceBlock: @"Via" display: (message.source != nil) inTemplate:tweetRowHTML];
	[self replaceBlock: @"InReplyTo" display: (message.inReplyToStatusIdentifier != nil) inTemplate:tweetRowHTML];
	[self replaceBlock: @"Retweet" display: (retweeterMessage != nil) inTemplate:tweetRowHTML];
	[self replaceBlock: @"Actions" display: (message.direct == NO) inTemplate:tweetRowHTML];
	
	return tweetRowHTML;
}

- (NSString*) tweetAreaFooterHTML {
	NSString *result = @"";
	
	if (networkIsReachable == NO) {
		result = @"<div class='status'>No Internet connection.</div>";
	} else if (currentAccount.xAuthToken == nil) {
		result = @"<div class='status'>Not logged in.</div>";
	} else if (actions.count > 0) {
		result = @"<div class='status'>Loading...</div>";
	} else if ([currentTimeline count] == 0) {
		result = @"<div class='status'>No messages.</div>";
	} else if (noOlderMessages) {
		result = @"";
	} else if ([currentTimeline count] < maxTweetsShown) {
		// Action to Load older messages 
		result = @"<div class='load_older'><a href='action:loadOlder'>Load older messages</a></div> ";
	}
	
	return result;
}

- (NSString*) timeStringSinceNow: (NSDate*) date {
	if (date == nil) return nil;
	
	NSString *result = nil;
	NSTimeInterval timeSince = -[date timeIntervalSinceNow] / 60.0 ; // in minutes
	if (timeSince < 48.0 * 60.0) { // If under 48 hours, report relative time
		int value;
		NSString *units;
		if (timeSince <= 1.5) { // report in seconds
			value = floor (timeSince * 60.0);
			units = @"second";
		} else if (timeSince < 90.0) { // report in minutes
			value = floor (timeSince);
			units = @"minute";
		} else { // report in hours
			value = floor (timeSince / 60.0);
			units = @"hour";
		}
		if (value == 1) {
			result = [NSString stringWithFormat:@"1 %@ ago", units];
		} else {
			result = [NSString stringWithFormat:@"%d %@s ago", value, units];
		}
	} else { // 48 hours or more, display the date
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		result = [dateFormatter stringFromDate:date];
	}
	return result;
}

- (void) replaceBlock:(NSString*)blockName display:(BOOL)display inTemplate:(NSMutableString*)template {
	// Find beginning and end of block tags
	NSString *openTag = [NSString stringWithFormat:@"{Block:%@}", blockName];
	NSString *closeTag = [NSString stringWithFormat:@"{/Block:%@}", blockName];
	
	if (display) {
		// Just remove the tags if we're displaying the block
		[template replaceOccurrencesOfString:openTag withString:@"" options:0 range:NSMakeRange(0, template.length)];
		[template replaceOccurrencesOfString:closeTag withString:@"" options:0 range:NSMakeRange(0, template.length)];
	} else {
		// Remove the entire block if we're not displaying it
		NSRange openRange = [template rangeOfString:openTag];
		NSRange closeRange = [template rangeOfString:closeTag];
		if (openRange.location == NSNotFound || closeRange.location == NSNotFound) return; // Can't find both tags
		NSRange replaceRange = NSMakeRange(openRange.location, closeRange.location + closeRange.length - openRange.location);
		[template replaceCharactersInRange:replaceRange withString:@""];
	}
}

- (NSString*)htmlFormattedString:(NSString*)string {
	NSMutableString *s = [NSMutableString stringWithString:string];
	
	NSString *foundText, *insertText, *urlText, *linkText;
	
	// Find URLs beginning with http: https*://[^ \t\r\n\v\f]*
	NSRange unprocessed, foundRange;
	unprocessed = NSMakeRange(0, s.length);
	while (unprocessed.location < s.length) {
		foundRange = [s rangeOfString: @"https*://[^ \t\r\n]*" options: NSRegularExpressionSearch range: unprocessed];
		if (foundRange.location == NSNotFound) break;
		
		// Replace URLs with link text
		urlText = [s substringWithRange: foundRange];
		linkText = [urlText substringFromIndex: [urlText hasPrefix:@"https"] ? 8 : 7];
		if ([linkText length] > 29) {
			linkText = [NSString stringWithFormat: @"%@...", [linkText substringToIndex:26]];
			insertText = [NSString stringWithFormat: @"<a href='%@'>%@</a>", urlText, linkText];
		} else {	
			insertText = [NSString stringWithFormat: @"<a href='%@'>%@</a>", urlText, linkText];
		}
		[s replaceCharactersInRange: foundRange withString: insertText];
		
		unprocessed.location = foundRange.location + [insertText length];
		unprocessed.length = s.length - unprocessed.location;
	}
	
	// Replace newlines and carriage returns with <br>
	[s replaceOccurrencesOfString:@"\r\n" withString:@"<br>" options:0 range:NSMakeRange(0, s.length)];
	[s replaceOccurrencesOfString:@"\n" withString:@"<br>" options:0 range:NSMakeRange(0, s.length)];
	[s replaceOccurrencesOfString:@"\r" withString:@"<br>" options:0 range:NSMakeRange(0, s.length)];
	
	// Replace tabs with a non-breaking space followed by a norma space
	[s replaceOccurrencesOfString:@"\t" withString:@"&nbsp; " options:0 range:NSMakeRange(0, s.length)];
	
	// Remove NULs
	[s replaceOccurrencesOfString:@"\0" withString:@"" options:0 range:NSMakeRange(0, s.length)];
	
	// Process letters outside of HTML tags. Break up long words with soft hyphens and detect @user strings.
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	unsigned int index = 0;
	unsigned int wordLength = 0;
	BOOL isInsideTag = NO;
	unichar c;
	while (index < s.length) {
		c = [s characterAtIndex:index];
		if (c == '<') {
			isInsideTag = YES;
		} else if (c == '>') {
			isInsideTag = NO;
			wordLength = 0;
		} else if (c == 160) { // non-breaking space
			wordLength++;
		} else if ([whitespace characterIsMember:c]) {
			wordLength = 0;
		} else {
			wordLength++;
		}
		
		if (isInsideTag == NO) {
			// Break up words longer than 20 chars
			if (wordLength >= 20) {
				[s replaceCharactersInRange:NSMakeRange(index, 0) withString:@"&shy;"]; // soft hyphen.
				index += 5;
				wordLength = 10; // Reset to 10 so that every 10 chars over 20, it gets a soft hyphen.
			}
			
			// @username: action link to User Page
			if (c == '@') {
				foundRange = [s rangeOfString: @"@[A-Za-z0-9_]*" options: NSRegularExpressionSearch range: NSMakeRange (index, s.length - index)];
				if (foundRange.location != NSNotFound && foundRange.length >= 2) {
					foundText = [s substringWithRange: NSMakeRange (foundRange.location + 1, foundRange.length - 1)];
					insertText = [NSString stringWithFormat: @"@<a href='action:user/%@'>%@</a>", foundText, foundText];
					[s replaceCharactersInRange: foundRange withString: insertText];
					index += insertText.length;
					wordLength = 0;
				}
			}
			
			// #hashtag: action link to Search
			if (c == '#') {
				foundRange = [s rangeOfString: @"#[A-Za-z0-9_]*" options: NSRegularExpressionSearch range: NSMakeRange (index, s.length - index)];
				if (foundRange.location != NSNotFound && foundRange.length >= 2) {
					foundText = [s substringWithRange:foundRange];
					insertText = [NSString stringWithFormat: @"<a href='action:search/%@'>%@</a>", foundText, foundText];
					[s replaceCharactersInRange: foundRange withString: insertText];
					index += insertText.length;
					wordLength = 0;
				}
			}
			
		}
		
		index++;
	}
	
	return s;
}	

#pragma mark UIWebView delegate methods

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	// Actions
	if ([[url scheme] isEqualToString:@"action"]) {
		//TwitterAccount *account = [twitter currentAccount];
		NSString *actionName = [url resourceSpecifier];
		NSScanner *scanner = [NSScanner scannerWithString:[actionName lastPathComponent]];
		SInt64 identifierInt64;
		[scanner scanLongLong: &identifierInt64];
		NSNumber *messageIdentifier = [NSNumber numberWithLongLong: identifierInt64];
		
		if ([actionName hasPrefix:@"fave"]) { // Add message to favorites or remove from favorites
			[self fave: messageIdentifier];
		} else if ([actionName hasPrefix:@"retweet"]) { // Retweet message
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
		} else if ([actionName hasPrefix:@"loadOlder"]) { // Load older
			[self loadOlderInCurrentTimeline];
		}
		
		return NO;
	} else if ([[url scheme] hasPrefix:@"http"]) {
		// Push a separate web browser for links
		[self showWebBrowserWithURLRequest:request];
		return NO;
	}
	
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView {
	[appDelegate incrementNetworkActionCount];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
	[appDelegate decrementNetworkActionCount];
	if (!webViewHasValidHTML) {
		webViewHasValidHTML = YES;

		// Automatically reload the current timeline over the network if this is the first time the web view is loaded.
		suppressNetworkErrorAlerts = YES;
		[self reloadCurrentTimeline];
	}
	
	// Hide Loading spinner if there are no actions
	if (actions.count == 0) {
		[self setLoadingSpinnerVisibility:NO];
	}
}

- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error {
	[appDelegate decrementNetworkActionCount];
	
	if ([error code] != -999) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString localizedStringWithFormat:@"Error %d", [error code]] message:[NSString localizedStringWithFormat:@"The page could not be loaded: \"%@\"", [error localizedDescription]] delegate:nil cancelButtonTitle:[NSString localizedStringWithFormat:@"OK"] otherButtonTitles:nil];
		[alert show];
		[alert release];
		networkIsReachable = NO;
	}
}

#pragma mark Popover delegate methods

- (void) compose:(ComposeViewController*)aCompose didSendMessage:(NSString*)text inReplyTo:(NSNumber*)inReplyTo {
	[self closeAllPopovers];
	[self updateStatus:text inReplyTo:inReplyTo];
}

- (void) compose:(ComposeViewController*)aCompose didRetweetMessage:(NSNumber*)identifier {
	[self closeAllPopovers];
	TwitterRetweetAction *action = [[[TwitterRetweetAction alloc] initWithMessageIdentifier:identifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didRetweet:);
	[self startTwitterAction:action];
}

- (void) lists:(ListsViewController*)lists didSelectList:(TwitterList*)list {
	[self closeAllPopovers];
	
	self.currentTimeline = list.statuses;
	
	// Style the page title
	NSString *pageTitle = list.fullName;
	NSArray *nameParts = [list.fullName componentsSeparatedByString:@"/"];
	if (nameParts.count == 2) {
		pageTitle = [NSString stringWithFormat:@"%@/<b>%@</b>", [nameParts objectAtIndex:0], [nameParts objectAtIndex:1]];
	}
	self.customPageTitle = pageTitle;
	self.customTabName = NSLocalizedString (@"List", @"tab");
	
	// Create Twitter action to load list statuses into the timeline.
	NSString *method = [NSString stringWithFormat:@"%@/lists/%@/statuses", list.username, list.identifier];
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:method] autorelease];
	[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"per_page"];
	suppressNetworkErrorAlerts = NO;
	[self reloadCurrentTimeline];
	
	// Rewrite and scroll web view
	[self rewriteTweetArea];	
	[self.webView scrollToTop];
}


- (void) search:(SearchViewController*)search didRequestQuery:(NSString*)query {
	[self searchForQuery:query];
}


#pragma mark Alert view

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	if (self.currentAlert == nil && !suppressNetworkErrorAlerts) { // Don't show another alert if one is already up.
		self.currentAlert = [[[UIAlertView alloc] initWithTitle:aTitle message:aMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[currentAlert show];
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	//[self rewriteTweetArea];
	//[self setLoadingSpinnerVisibility:NO];
	self.currentAlert = nil;
}


@end
