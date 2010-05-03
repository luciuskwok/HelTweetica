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
#define kMaxNumberOfMessagesShown 800

// Imports
#import "TimelineViewController.h"
#import "LKWebView.h"
#import "HelTweeticaAppDelegate.h"

#import "UserPageViewController.h"
#import "WebBrowserViewController.h"

#import "TwitterFavoriteAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"
#import "TwitterSearchAction.h"



@implementation TimelineViewController
@synthesize webView, composeButton, twitter, actions, defaultCount;
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
	// Use Twitter instance from app delegate
	appDelegate = [[UIApplication sharedApplication] delegate];
	self.twitter = appDelegate.twitter;
	
	// String to pass in the count, per_page, and rpp parameters.
	self.defaultCount = @"100";
	
	// List of currently active network connections
	self.actions = [NSMutableArray array];
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
}

- (void)dealloc {
	[webView release];
	[twitter release];
	[actions release];
	[defaultCount release];
 
	[currentAccount release];
	[currentTimeline release];
	[currentTimelineAction release];
	[customPageTitle release];
	[customTabName release];

	[super dealloc];
}

#pragma mark UIView lifecycle

- (void) viewDidLoad {
	[super viewDidLoad];
	[self reloadWebView];
	automaticReload = YES; // Automatically reload after web view is done rendering.
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[refreshTimer invalidate];
	refreshTimer = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


#pragma mark TwitterAction

- (void) startTwitterAction:(TwitterAction*)action {
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

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	// Deal with status codes 400 to 402 and 404 and up.
	if ((action.statusCode >= 400) && (action.statusCode != 403)) {
		[self showNetworkErrorAlertForStatusCode:action.statusCode];
	}
	[self removeTwitterAction:action];
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	NSString *title = NSLocalizedString (@"Network error", @"Alert");
	[self showAlertWithTitle:title message:[error localizedDescription]];
	[actions removeObject: action];
}


#pragma mark TwitterAction - Timeline

// TODO: add own RTs to home timeline
// See http://apiwiki.twitter.com/Twitter-REST-API-Method%3A-statuses-retweeted_by_me

- (void)reloadCurrentTimeline {
	if (currentAccount == nil || currentAccount.xAuthToken == nil) {
		[self setLoadingSpinnerVisibility:NO];
		return; // No current account or not logged in.
	}
	
	TwitterAction *action = self.currentTimelineAction;
	if (action == nil) return; // No action to reload.

	BOOL isFavorites = [action.twitterMethod isEqualToString:@"favorites"];
	
	// Set the since_id parameter if there already are messages in the current timeline, except for the favorites timeline, because older tweets can be faved.
	NSNumber *newerThan = nil;
	if (([currentTimeline count] > 10) && (isFavorites == NO)) {
		TwitterMessage *message = [currentTimeline objectAtIndex: 0];
		NSTimeInterval staleness = -[message.receivedDate timeIntervalSinceNow];
		if (staleness < kMaxMessageStaleness) {
			newerThan = message.identifier;
		}
	}
	
	if (newerThan)
		[action.parameters setObject:[newerThan stringValue] forKey:@"since_id"];
	
	// Prepare action and start it. 
	action.completionTarget= self;
	action.completionAction = @selector(didReloadCurrentTimeline:);
	[self startTwitterAction:action];
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
}

- (void) startLoadingCurrentTimeline {
	[self reloadCurrentTimeline];
	[self rewriteTweetArea];
}

- (void) fireRefreshTimer:(NSTimer*)timer {
	// Clear pointer to timer because this is a non-recurring timer.
	[refreshTimer invalidate];
	refreshTimer = nil;
	
	// If there are actions already pending, reschedule refresh 
	if ([actions count] == 0) {
		CGPoint scrollPosition = [self.webView scrollPosition];
		if (scrollPosition.y == 0.0f && automaticReload == NO) {
			// If scrolled to top, load new tweets
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

- (void)didUpdateStatus:(TwitterUpdateStatusAction *)action {
	if ((action.statusCode < 400) || (action.statusCode == 403)) { // Twitter returns 403 if user tries to post duplicate status updates.
		// Remove message text from compose screen.
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:@"" forKey:@"messageContent"];
		[defaults removeObjectForKey:@"inReplyTo"];
		
		// Reload timeline
		[self startLoadingCurrentTimeline];
	} else {
		// Status update was not successful, so report the error.
		[self showNetworkErrorAlertForStatusCode:action.statusCode];
	}
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

- (void)retweet:(NSNumber*)messageIdentifier {
	TwitterRetweetAction *action = [[[TwitterRetweetAction alloc] initWithMessageIdentifier:messageIdentifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didRetweet:);
	[self startTwitterAction:action];
}

- (void)didRetweet:(TwitterRetweetAction *)action {
	NSString *title = NSLocalizedString (@"Retweeted!", @"");
	NSString *message = NSLocalizedString (@"You just retweeted that message.", @"");
	[self showAlertWithTitle:title message:message];
}

- (void) replyToMessage: (NSNumber*)identifier {
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:currentAccount] autorelease];
	compose.delegate = self;
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
	ComposeViewController *compose = [[[ComposeViewController alloc] initWithAccount:currentAccount] autorelease];
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
	}
	compose.inReplyTo = identifier;
	
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

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// TODO: show conversation page
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
	[self.webView setDocumentElement:@"spinner" visibility:isVisible];
}

- (void) rewriteTweetArea {
	// Replace text in tweet area with new statuses
	NSString *result = [self.webView setDocumentElement:@"tweet_area" innerHTML:[self tweetAreaHTML]];
	if ([result length] == 0) { // If the result of the JavaScript call is empty, there was an error.
		NSLog (@"JavaScript error in refreshing tweet area. Reloading entire web view.");
		[self reloadWebView];
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
	
	NSArray *timeline = currentTimeline; 
	
	if ((timeline != nil) && ([timeline count] != 0)) {
		int totalMessages = [timeline count];
		int displayedCount = (totalMessages < kMaxNumberOfMessagesShown) ? totalMessages : kMaxNumberOfMessagesShown;
		
		// Count and oldest
		TwitterMessage *message, *retweeterMessage;
		
		[html appendString:@"<div class='tweet_table'> "];
		
		// Page title for Lists and Search
		if (customPageTitle) {
			// Put the title inside a regular tweet table row.
			[html appendString:@"<div class='tweet_row'><div class='tweet_avatar'></div><div class='tweet_content'>"];
			[html appendFormat:@"<div class='page_title'>%@</div>", customPageTitle];
			[html appendString:@"</div><div class='tweet_actions'> </div></div>"];
		}
		
		// Template for tweet_row
		NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
		NSError *error = nil;
		NSString *tweetRowTemplate = [NSString stringWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"tweet-row-template.html"] encoding:NSUTF8StringEncoding error:&error];
		if (error != nil)
			NSLog (@"Error loading tweet-row-template.html: %@", [error localizedDescription]);
		NSMutableString *tweetRowHTML;
		
		NSAutoreleasePool *pool;
		BOOL isFavorite;
		int index;
		for (index=0; index<displayedCount; index++) {
			pool = [[NSAutoreleasePool alloc] init];
			message = [timeline objectAtIndex:index];
			//isFavorite = message.favorite; // Is the original tweet or the retweeter's tweet supposed to be the one that gets the star? If the latter, uncomment this.
			retweeterMessage = nil;
			
			// Swap retweeted message with root message
			if (message.retweetedMessage != nil) {
				retweeterMessage = message;
				message = retweeterMessage.retweetedMessage;
			}
			
			// Favorites
			isFavorite = (message.favorite || retweeterMessage.favorite);
			
			// Create mutable copy of template
			tweetRowHTML = [NSMutableString stringWithString:tweetRowTemplate];
			
			// Fields for replacement
			NSString *screenName = message.screenName ? message.screenName : @"";
			NSString *messageIdentifier = message.identifier ? [message.identifier stringValue] : @"";
			NSString *profileImageURL = message.avatar ? message.avatar : @"";
			NSString *retweetIcon = retweeterMessage ? @"<img src='retweet.png'>" : @"";
			NSString *lockIcon = [message isLocked] ? @"<img src='lock.png'>" : @"";
			NSString *content = message.content ? [message layoutSafeContent] : @"";
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
			[self replaceBlock: @"InReplyTo" display: (message.inReplyToScreenName != nil) inTemplate:tweetRowHTML];
			[self replaceBlock: @"Retweet" display: (retweeterMessage != nil) inTemplate:tweetRowHTML];
			[self replaceBlock: @"Actions" display: (message.direct == NO) inTemplate:tweetRowHTML];
			
			// Append row to table
			[html appendString:tweetRowHTML];
			
			[pool release];
		}
		[html appendString:@"</div> "]; // Close tweet_table
		
		/*// Action to Load older messages 
		 if ((displayedCount == totalMessages) && (selectedTab >= 0) && (selectedTab < 3))
		 [html appendString:@"<div class='time' style='text-align:center;'><a href='action:loadOlder'>Load older messages</a></div>\n"];*/
		
	} else { // No tweets or Loading or Not logged in
		if (currentAccount.xAuthToken == nil) {
			[html appendString: @"<div class='status'>Not logged in.</div>"];
		} else if (actions.count > 0)
			[html appendString: @"<div class='status'>Loading...</div>"];
		else
			[html appendString: @"<div class='status'>No messages.</div>"];
	}
	
	return html;
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

- (void)webViewDidStartLoad:(UIWebView *)aWebView {
	[appDelegate incrementNetworkActionCount];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
	[appDelegate decrementNetworkActionCount];
	if (automaticReload) {
		[self reloadCurrentTimeline];
		automaticReload = NO;
	}
}

- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error {
	[appDelegate decrementNetworkActionCount];
	
	if ([error code] != -999) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString localizedStringWithFormat:@"Error %d", [error code]] message:[NSString localizedStringWithFormat:@"The page could not be loaded: \"%@\"", [error localizedDescription]] delegate:nil cancelButtonTitle:[NSString localizedStringWithFormat:@"OK"] otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

#pragma mark Popover delegate methods

- (void) sendStatusUpdate:(NSString*)text inReplyTo:(NSNumber*)inReplyTo {
	[self closeAllPopovers];
	[self updateStatus:text inReplyTo:inReplyTo];
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
	[currentTimelineAction.parameters setObject:defaultCount forKey:@"per_page"];
	[self reloadCurrentTimeline];
	
	// Rewrite and scroll web view
	[self rewriteTweetArea];	
	[self.webView scrollToTop];
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
	[self closeAllPopovers];
	
	self.currentTimeline = [NSMutableArray array]; // Always start with an empty array of messages for Search.
	self.customPageTitle = [NSString stringWithFormat: @"Search for &ldquo;<b>%@</b>&rdquo;", [self htmlSafeString:query]];
	self.customTabName = NSLocalizedString (@"Results", @"tab");
	
	// Create Twitter action to load search results into the current timeline.
	TwitterSearchAction *action = [[[TwitterSearchAction alloc] initWithQuery:query count:defaultCount] autorelease];
	self.currentTimelineAction = action;
	[self reloadCurrentTimeline];
	
	// Rewrite and scroll web view
	[self rewriteTweetArea];	
	[self.webView scrollToTop];
}


#pragma mark Alert view

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	if (self.currentAlert == nil) { // Don't show another alert if one is already up.
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
