//
//  TimelineHTMLController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/22/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TimelineHTMLController.h"


#import "TwitterAction.h"
#import "TwitterFavoriteAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterUpdateStatusAction.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"





// Constants
enum { kDefaultMaxTweetsShown = 300 };
static NSString *kTimelineIdentifier = @"Timeline";
static NSString *kMentionsIdentifier = @"Mentions";
static NSString *kDirectMessagesIdentifier = @"Direct";
static NSString *kFavoritesIdentifier = @"Favorites";



@implementation TimelineHTMLController
@synthesize webView, twitter, account, timeline, messages, actions;
@synthesize webViewHasValidHTML, isLoading, noInternetConnection, suppressNetworkErrorAlerts;
@synthesize customPageTitle, customTabName, defaultLoadCount;
@synthesize delegate;


- (id)init {
	self = [super init];
	if (self) {
		
		// Load the HTML templates.
		tweetRowTemplate = [[self loadHTMLTemplate:@"tweet-row-template"] retain];
		tweetMentionRowTemplate = [[self loadHTMLTemplate:@"tweet-row-mention-template"] retain];
		tweetGapRowTemplate = [[self loadHTMLTemplate:@"load-gap-template"] retain];
		
		// Loading template
		loadingHTML = [@"<div class='status'><img class='status_spinner_image' src='spinner.gif'> Loading...</div>"retain];

		// Misc
		isLoading = YES;
		maxTweetsShown = kDefaultMaxTweetsShown; 
		self.defaultLoadCount = [NSNumber numberWithInt:50]; // String to pass in the count, per_page, and rpp parameters.
		self.actions = [NSMutableArray array]; // List of currently active network connections
		
	}
	return self;
}

- (void)dealloc {
	[webView release];
	
	[twitter release];
	[account release];
	[timeline release];
	[messages release];
	[actions release];
	
	[tweetRowTemplate release];
	[tweetMentionRowTemplate release];
	[tweetGapRowTemplate release];
	[loadingHTML release];
	
	[customPageTitle release];
	[customTabName release];
	
	[defaultLoadCount release];
	
	[super dealloc];
}

#pragma mark Timeline selection

- (void)selectHomeTimeline {
	self.customTabName = kTimelineIdentifier;
	self.timeline = account.homeTimeline;
	self.messages = [timeline statusUpdatesWithLimit:maxTweetsShown];
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/home_timeline"] autorelease];
	[self.timeline.loadAction.parameters setObject:defaultLoadCount forKey:@"count"];
	[self startLoadingCurrentTimeline];
}

- (void)selectMentionsTimeline {
	self.customTabName = kMentionsIdentifier;
	self.timeline = account.mentions;
	self.messages = [timeline statusUpdatesWithLimit:maxTweetsShown];
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/mentions"] autorelease];
	[self.timeline.loadAction.parameters setObject:defaultLoadCount forKey:@"count"];
	[self startLoadingCurrentTimeline];
}

- (void)selectDirectMessageTimeline {
	self.customTabName = kDirectMessagesIdentifier;
	self.timeline = account.directMessages;
	self.messages = [timeline statusUpdatesWithLimit:maxTweetsShown];
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"direct_messages"] autorelease];
	[self.timeline.loadAction.parameters setObject:defaultLoadCount forKey:@"count"];
	[self startLoadingCurrentTimeline];
}

- (void)selectFavoritesTimeline {
	self.customTabName = kFavoritesIdentifier;
	self.timeline = account.favorites;
	self.messages = [timeline statusUpdatesWithLimit:maxTweetsShown];
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	// Favorites always loads 20 per page. Cannot change the count.
	[self startLoadingCurrentTimeline];
}

- (void)startLoadingCurrentTimeline {
	suppressNetworkErrorAlerts = NO;
	if (noInternetConnection == NO) {
		[self loadTimeline:timeline];
	}
	[self rewriteTweetArea];
	
	// Notify delegate that a different timeline was selected.
	if ([delegate respondsToSelector:@selector(didSelectTimeline:)])
		[delegate didSelectTimeline:timeline];
}

#pragma mark Loading

- (void)loadTimeline:(TwitterTimeline*)aTimeline {
	isLoading = YES;
	self.timeline = aTimeline;
	self.messages = [timeline statusUpdatesWithLimit:maxTweetsShown];
	timeline.delegate = self;
	[timeline reloadNewer];
}

- (void)loadOlderWithMaxIdentifier:(NSNumber*)maxIdentifier {
	// Replace link to load the gap or load older with a Loading spinner
	if (maxIdentifier) { 
		// Load gap
		NSString *element = [NSString stringWithFormat:@"gap-%@", [maxIdentifier stringValue]];
		[self.webView setDocumentElement:element innerHTML:loadingHTML];
	} else {
		[self.webView setDocumentElement:@"footer" innerHTML:loadingHTML];
	}
	isLoading = YES;
	timeline.delegate = self;
	[timeline loadOlderWithMaxIdentifier:maxIdentifier];
}

- (void) timeline:(TwitterTimeline *)aTimeline didLoadWithAction:(TwitterLoadTimelineAction *)action {
	// Twitter cache.
	if ([action.twitterMethod hasPrefix:@"direct_messages"]) {
		[twitter addDirectMessages:action.loadedMessages];
	} else {
		[twitter addStatusUpdates:action.loadedMessages];
		[twitter addStatusUpdates:action.retweetedMessages];
	}
	[twitter addOrReplaceUsers:action.users];
	
	// Timeline
	[aTimeline addMessages:action.loadedMessages updateGap:YES];

	isLoading = NO;
	
	if (timeline == aTimeline) {
		// User may have changed timelines or accounts by the time this method is called, because network operations can take a while.
		
		// To be safe, only update Favorites if a different timeline was not selected.
		[account addFavorites:action.favoriteMessages];
	
		// Update our array of messages with the latest in the timeline.
		self.messages = [timeline statusUpdatesWithLimit: maxTweetsShown];
		[self rewriteTweetArea];	
	}
}


- (void)loadList:(TwitterList*)list {
	TwitterTimeline *listTimeline = list.statuses;
	
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
	listTimeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:method] autorelease];
	[listTimeline.loadAction.parameters setObject:defaultLoadCount forKey:@"per_page"];
	suppressNetworkErrorAlerts = NO;
	
	// Load timeline
	[self loadTimeline: listTimeline];
	
	// Rewrite and scroll web view
	[self rewriteTweetArea];	
	[self.webView scrollToTop];

	// Notify delegate that a different timeline was selected.
	if ([delegate respondsToSelector:@selector(didSelectTimeline:)])
		[delegate didSelectTimeline:timeline];

}

#pragma mark TwitterAction

- (void)startTwitterAction:(TwitterAction*)action {
	// Add the action to the array of actions, and updates the network activity spinner
	[actions addObject: action];
	
	// Set up Twitter action
	action.delegate = self;
	action.consumerToken = account.xAuthToken;
	action.consumerSecret = account.xAuthSecret;
	
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
	if (suppressNetworkErrorAlerts) return;
	
	// Show alert with error code and message.
	NSString *title, *message;
	
	if (statusCode == 400) { // Bad request, or rate limit exceeded
		title = NSLocalizedString (@"Rate limit exceeded", @"Alert");
		message = NSLocalizedString (@"Please wait and try again later. (400)", @"Alert");
	} else if (statusCode == 401) { // Unauthorized
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
	
	if ([delegate respondsToSelector:@selector(showAlertWithTitle:message:)])
		[delegate showAlertWithTitle:title message:message];
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
	noInternetConnection = NO;
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	if (suppressNetworkErrorAlerts == NO) {
		NSString *title = NSLocalizedString (@"Network error", @"Alert");
		if ([delegate respondsToSelector:@selector(showAlertWithTitle:message:)])
			[delegate showAlertWithTitle:title message:[error localizedDescription]];
	}
	
	[self removeTwitterAction: action];
	noInternetConnection = YES;
}

#pragma mark TwitterAction - Misc

- (void) updateStatus:(NSString*)text inReplyTo:(NSNumber*)messageIdentifier {
	TwitterUpdateStatusAction *action = [[[TwitterUpdateStatusAction alloc] initWithText:text inReplyTo:messageIdentifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didUpdateStatus:);
	[self startTwitterAction:action];
}

- (void)didUpdateStatusSuccessfully {
	noInternetConnection = NO;
	
	// Remove message text from compose screen.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:@"" forKey:@"messageContent"];
	[defaults removeObjectForKey:@"inReplyTo"];
	[defaults removeObjectForKey:@"originalRetweetContent"];
	
	// Reload timeline
	[self loadTimeline:timeline];
}

- (void)didUpdateStatus:(TwitterUpdateStatusAction *)action {
	if ((action.statusCode < 400) || (action.statusCode == 403)) { // Twitter returns 403 if user tries to post duplicate status updates.
		[self didUpdateStatusSuccessfully];
	} else {
		// Status update was not successful, so report the error.
		[self showNetworkErrorAlertForStatusCode:action.statusCode];
	}
}

- (void)retweet:(NSNumber *)messageIdentifier {
	TwitterRetweetAction *action = [[[TwitterRetweetAction alloc] initWithMessageIdentifier:messageIdentifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didRetweet:);
	[self startTwitterAction:action];
}	

- (void)didRetweet:(id)action {
	[self didUpdateStatusSuccessfully];
}

- (void) fave: (NSNumber*) messageIdentifier {
	noInternetConnection = NO;
	
	TwitterStatusUpdate *message = [twitter statusUpdateWithIdentifier: messageIdentifier];
	if (message == nil) {
		NSLog (@"Cannot find the message to fave (or unfave). id == %@", messageIdentifier);
		return;
	}
	
	BOOL isFave = [account messageIsFavorite:messageIdentifier];
	
	TwitterFavoriteAction *action = [[[TwitterFavoriteAction alloc] initWithMessage:message destroy:isFave] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didFave:);
	[self startTwitterAction:action];
}

- (void)didFave:(TwitterFavoriteAction *)action {
	TwitterStatusUpdate *message = [action message];
	if (action.success == NO) return;
	BOOL isFave = !action.destroy;
	
	// Change the display of the star next to tweet in root view
	NSString *element = [NSString stringWithFormat:@"star-%@", [message.identifier stringValue]];
	NSString *html = isFave ? @"<img src='action-4-on.png'>" : @"<img src='action-4.png'>";
	[self.webView setDocumentElement:element innerHTML:html];
	
	// Remove from favorites timeline
	if (isFave) {
		[account addFavorites:[NSArray arrayWithObject:message]];
	} else {
		[account removeFavorite:message.identifier];
	}
}

#pragma mark Web view updating

- (void)loadWebView {
	// Load template and replace special tags with data
	NSString *template = [self webPageTemplate];
	if (template == nil) return;
	NSMutableString *html = [NSMutableString stringWithString:template];
	
	// Use the timeline HTML controller to create the HTML content.
	NSString *tweetAreaHTML = @"<div class='login'><a href='action:login'>Please log in.</a></div>";
	NSString *currentAccountHTML = @"";
	NSString *tabAreaHTML = @"";
	
	if (account.screenName != nil) {
		tweetAreaHTML = [self tweetAreaHTML];
		currentAccountHTML = [self currentAccountHTML];
		tabAreaHTML = [self tabAreaHTML];
	}
	
	// Replace custom tags with HTML
	[html replaceOccurrencesOfString:@"<tweetAreaHTML/>" withString:tweetAreaHTML options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"<currentAccountHTML/>" withString:currentAccountHTML options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"<tabAreaHTML/>" withString:tabAreaHTML options:0 range:NSMakeRange(0, html.length)];
	
	[self.webView loadHTMLString:html];
	
	// Start refresh timer so that the timestamps are always accurate
	[self scheduleRefreshTimer];
}

- (void)setLoadingSpinnerVisibility:(BOOL)isVisible {
	if (webViewHasValidHTML)
		[self.webView setDocumentElement:@"spinner" visibility:isVisible];
}

- (void)rewriteTweetArea {
	
	if (webViewHasValidHTML) {
		// Replace tab area HTML with current tab
		if (customTabName != nil) {
			[self.webView setDocumentElement:@"tab_area" innerHTML:[self tabAreaHTML]];
		}
	
		// Replace tweet area HTML with new tweets
		NSString *result = [self.webView setDocumentElement:@"tweet_area" innerHTML:[self tweetAreaHTML]];
		if ([result length] == 0) { // If the result of the JavaScript call is empty, there was an error.
			NSLog (@"JavaScript error in refreshing tweet area. Reloading entire web view.");
			[self loadWebView];
		}
	}
	
	// Start refresh timer so that the timestamps are always accurate
	[self scheduleRefreshTimer];
}

#pragma mark Web actions

- (BOOL)handleWebAction:(NSString*)action {
	BOOL handled = YES;
	NSNumber *messageIdentifier = [self number64WithString:[action lastPathComponent]];
	
	// Select a timeline
	if ([action isEqualToString:kTimelineIdentifier]) { // Home Timeline
		self.customPageTitle = nil; // Reset the custom page title.
		[self selectHomeTimeline];
	} else if ([action isEqualToString:kMentionsIdentifier]) { // Mentions
		self.customPageTitle = nil; // Reset the custom page title.
		[self selectMentionsTimeline];
	} else if ([action isEqualToString:kFavoritesIdentifier]) { // Favorites
		self.customPageTitle = nil; // Reset the custom page title.
		[self selectFavoritesTimeline];
	}
	
	// Other actions
	else if ([action hasPrefix:@"fave"]) { // Add message to favorites or remove from favorites
		[self fave:messageIdentifier];
	} else if ([action hasPrefix:@"loadOlder"]) { // Load older
		[self loadOlderWithMaxIdentifier:nil];
	} else if ([action hasPrefix:@"loadGap"]) { // Load gap
		[self loadOlderWithMaxIdentifier:messageIdentifier];
	} else {
		handled = NO;
	}
	return handled;
}

- (NSNumber*)number64WithString:(NSString*)string {
	if (string == nil) return nil;
	
	NSScanner *scanner = [NSScanner scannerWithString:string];
	SInt64 identifierInt64;
	if ([scanner scanLongLong: &identifierInt64])
		return [NSNumber numberWithLongLong: identifierInt64];
	return nil;
}


#pragma mark Refresh timer

- (void)scheduleRefreshTimer {
	[refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
}

- (void)invalidateRefreshTimer {
	[refreshTimer invalidate];
	refreshTimer = nil;
}

- (void)fireRefreshTimer:(NSTimer *)timer {
	// Clear pointer to timer because this is a non-recurring timer.
	[refreshTimer invalidate];
	refreshTimer = nil;
	
	if (actions.count == 0 && webViewHasValidHTML) {
		CGPoint scrollPosition = [self.webView scrollPosition];
		if (scrollPosition.y == 0.0f && !noInternetConnection) {
			// Only reload from the network if the scroll position is at the top, the web view has been loaded, the network is reachable, and no popovers are showing.
			suppressNetworkErrorAlerts = YES; // Don't show an error alert for auto reloads.
			[self loadTimeline:timeline];
		} else {
			// Don't load new statuses if scroll position is below top.
			[self rewriteTweetArea];
		}
	} else {
		// If there are actions already pending, reschedule refresh 
		refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
	}
}

#pragma mark HTML

- (NSString *)loadHTMLTemplate:(NSString *)templateName {
	// Load main template
	NSError *error = nil;
	NSString *filePath = [[NSBundle mainBundle] pathForResource:templateName ofType:@"html"];
	NSString *html = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
	if (error != nil)
		NSLog (@"Error loading %@.html: %@", templateName, [error localizedDescription]);
	return html;
}

- (NSString *)webPageTemplate {
	return [self loadHTMLTemplate:@"main-template"];
}

- (NSString *)currentAccountHTML {
	return [NSString stringWithFormat:@"<a href='action:user/%@'>%@</a>", account.screenName, account.screenName];
}

- (NSString *)tabAreaHTML {
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];
	
	int selectedTab = 0;
	NSString *tabName = self.customTabName;
	if ([tabName isEqualToString: kTimelineIdentifier] || (tabName == nil)) {
		selectedTab = 1;
	} else if ([tabName isEqualToString: kMentionsIdentifier]) {
		selectedTab = 2;
	} else if ([tabName isEqualToString: kDirectMessagesIdentifier]) {
		selectedTab = 3;
	} else if ([tabName isEqualToString: kFavoritesIdentifier]) {
		selectedTab = 4;
	} else {
		selectedTab = 5;
	}
	
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Timeline';\">Timeline</div>", (selectedTab == 1)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Mentions';\">Mentions</div>", (selectedTab == 2)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Direct';\">Direct</div>", (selectedTab == 3)? @"" : @"de"];
	[html appendFormat:@"<div class='tab %@selected' onclick=\"location.href='action:Favorites';\">Favorites</div>", (selectedTab == 4)? @"" : @"de"];
	if (selectedTab == 5)
		[html appendFormat:@"<div class='tab selected'>%@</div>", tabName];
	
	return html;
}

- (NSString*) tweetAreaHTML {
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];

	// Page Title for Lists and Search
	if (customPageTitle) {
		// Put the title inside a regular tweet table row.
		[html appendString:@"<div class='tweet_table'><div class='tweet_row'><div class='tweet_avatar'></div><div class='tweet_content'>"];
		[html appendFormat:@"<div class='page_title'>%@</div>", customPageTitle];
		[html appendString:@"</div></div></div>"];
	}
	
	[html appendString:@"<div class='tweet_table'> "];

	// Template for tweet_row
	for (int index=0; index<messages.count; index++) {
		[html appendString: [self tweetRowHTMLForRow:index]];
	}
	
	[html appendString:@"</div> "]; // Close tweet_table
	
	// Footer
	[html appendString:@"<div id='footer'>"];
	[html appendString:[self tweetAreaFooterHTML]];
	[html appendString:@"</div> "]; // Close footer
	
	return html;
}

- (NSString *)tweetRowTemplateForRow:(int)row {
	// Highlight Mentions
	NSString *screenName = [NSString stringWithFormat:@"@%@", account.screenName];
	TwitterStatusUpdate *message = [messages objectAtIndex:row];
	if (message.retweetedStatusIdentifier) {
		TwitterStatusUpdate *retweeted = [twitter statusUpdateWithIdentifier:message.retweetedStatusIdentifier];
		if (retweeted)
			message = retweeted;
	}
	NSRange foundRange = [message.text rangeOfString:screenName options:NSCaseInsensitiveSearch];
	if (foundRange.location != NSNotFound) 
		return tweetMentionRowTemplate;
	
	return tweetRowTemplate;
}

- (NSString *)tweetRowHTMLForRow:(int)row {
	TwitterStatusUpdate *message = [messages objectAtIndex:row];
	TwitterStatusUpdate *retweeterMessage = nil;
	
	// Skip messages with invalid identifiers
	if ([message.identifier compare:[NSNumber numberWithInt:10000]] == NSOrderedAscending) return @"";
	
	// Swap retweeted message with root message
	if ([message.retweetedStatusIdentifier longLongValue] != 0) {
		retweeterMessage = message;
		message = [twitter statusUpdateWithIdentifier:message.retweetedStatusIdentifier];
	}
	
	// Favorites
	BOOL isFavorite = [account messageIsFavorite:message.identifier];
	
	// Set up dictionary with variables to substitute
	NSMutableDictionary *substitutions = [NSMutableDictionary dictionary];
	if (message.userScreenName)
		[substitutions setObject:message.userScreenName forKey:@"screenName"];
	if (message.identifier)
		[substitutions setObject:[message.identifier stringValue] forKey:@"messageIdentifier"];
	if (message.profileImageURL)
		[substitutions setObject:message.profileImageURL forKey:@"profileImageURL"];
	if (retweeterMessage)
		[substitutions setObject:@"<img src='retweet.png'>" forKey:@"retweetIcon"];
	if ([message isLocked])
		[substitutions setObject:@"<img src='lock.png'>" forKey:@"lockIcon"];
	if (message.text)
		[substitutions setObject:[self htmlFormattedString:message.text] forKey:@"content"];
	if (message.createdDate) 
		[substitutions setObject:[self timeStringSinceNow: message.createdDate] forKey:@"createdDate"];
	if (message.source) 
		[substitutions setObject:message.source forKey:@"via"];
	if (message.inReplyToScreenName) 
		[substitutions setObject:message.inReplyToScreenName forKey:@"inReplyToScreenName"];
	if (retweeterMessage.userScreenName) 
		[substitutions setObject:retweeterMessage.userScreenName forKey:@"retweetedBy"];
	if (isFavorite) 
		[substitutions setObject:@"-on" forKey:@"faveImageSuffix"];
	if ([self.customTabName isEqualToString:kDirectMessagesIdentifier] == NO) 
		[substitutions setObject:@"YES" forKey:@"actions"];
	
	// Use scanner to replace curly-bracketed variables with values
	NSScanner *scanner = [NSScanner scannerWithString:[self tweetRowTemplateForRow: row]];
	NSMutableString *tweetRowHTML = [[[NSMutableString alloc] init] autorelease];
	NSString *scannedString, *key, *value;
	BOOL displayBlock = YES;
	
	// Set scanner to include whitespace
	[scanner setCharactersToBeSkipped:nil];
	
	while ([scanner isAtEnd] == NO) {
		// Scan characters up to opening of variable curly brace
		if ([scanner scanUpToString:@"{" intoString:&scannedString] && displayBlock) {
			[tweetRowHTML appendString:scannedString];
		}
		
		// Scan name of variable or block
		if ([scanner scanUpToString:@"}" intoString:&scannedString]) {
			if ([scannedString hasPrefix:@"{Block:"]) {
				// Block
				if ([scannedString length] > 7) {
					key = [scannedString substringFromIndex:7];
					value = [substitutions objectForKey:key];
					displayBlock = (value != nil);
				}
			} else if ([scannedString hasPrefix:@"{/Block"]) {
				// End Block
				displayBlock = YES;
			} else {
				// Variable
				if (displayBlock && [scannedString length] > 1) {
					key = [scannedString substringFromIndex:1];
					value = [substitutions objectForKey:key];
					if (value) 
						[tweetRowHTML appendString:value];
				}
			}
		}
		
		// Scan past closing curly brace
		[scanner scanString:@"}" intoString:nil];
	}
	
	// Append "Load gap" row if needed
	BOOL gap = [timeline hasGapAfter:message.identifier];
	BOOL endRow = (row >= maxTweetsShown - 1 || row >= messages.count - 1);
	NSString *messageIdentifier = [message.identifier stringValue];
	if (retweeterMessage) 
		messageIdentifier = [retweeterMessage.identifier stringValue];
	if (gap && !endRow) {
		NSMutableString *gapRowHTML = [NSMutableString stringWithString:tweetGapRowTemplate];
		[gapRowHTML replaceOccurrencesOfString:@"{gapIdentifier}" withString:messageIdentifier options:0 range:NSMakeRange(0, gapRowHTML.length)];
		[tweetRowHTML appendString:gapRowHTML];
	}
	
	return tweetRowHTML;
}

- (NSString*) tweetAreaFooterHTML {
	NSString *result = @"";
	
	if (noInternetConnection) {
		result = @"<div class='status'>No Internet connection.</div>";
	} else if (account.xAuthToken == nil) {
		result = @"<div class='status'><a href='action:login'>Please log in.</a></div>";
	} else if (isLoading) { // (actions.count > 0 || !webViewHasValidHTML)
		result = loadingHTML;
	} else if (messages.count == 0) {
		result = @"<div class='status'>No messages.</div>";
	} else if (timeline.noOlderMessages) {
		result = @"";
	} else if (messages.count < maxTweetsShown) {
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

- (NSString *)stringWithLinksToURLsWithPrefix:(NSString *)prefix inString:(NSString *)string {
	NSMutableString *result = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSCharacterSet *nonURLSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n\"'"];
	[scanner setCharactersToBeSkipped:nil];
	NSString *scanned;
	
	while ([scanner isAtEnd] == NO) {
		if ([scanner scanUpToString:prefix intoString:&scanned]) 
			[result appendString:scanned];
		if ([scanner scanUpToCharactersFromSet:nonURLSet intoString:&scanned]) {
			// Replace URLs with link text
			NSString *linkText = [scanned substringFromIndex: [scanned hasPrefix:@"https"] ? 8 : 7];
			if ([linkText length] > 29) {
				linkText = [NSString stringWithFormat: @"%@...", [linkText substringToIndex:26]];
			}
			[result appendFormat: @"<a href='%@'>%@</a>", scanned, linkText];
		}
	}
	return result;
}

/*
- (NSString *)stringWithAction:(NSString*)action prefix:(NSString *)prefix removePrefix:(BOOL)removePrefix inString:(NSString *)string {
	NSMutableString *result = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSCharacterSet *endSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz_0123456789"];
	[scanner setCharactersToBeSkipped:nil];
	NSString *scanned;
	
	while ([scanner isAtEnd] == NO) {
		if ([scanner scanUpToString:prefix intoString:&scanned]) 
			[result appendString:scanned];
		if ([scanner scanUpToCharactersFromSet:endSet intoString:&scanned]) {
			NSString *linkText = scanned;
			if ([linkText length] > 30)
				linkText = [NSString stringWithFormat: @"%@...", [linkText substringToIndex:28]];
			if (removePrefix && [scanned hasPrefix:prefix])
				scanned = [scanned substringFromIndex:prefix.length];
			[result appendFormat: @"<a href='action:%@/%@'>%@</a>", action, scanned, linkText];
		}
	}
	return result;
}

- (NSString *)stringWithActionLinksInString:(NSString *)string {
	string = [self stringWithAction:@"user" prefix:@"@" removePrefix:YES inString:string];
	string = [self stringWithAction:@"search" prefix:@"#" removePrefix:NO inString:string];
	return string;
}
 */

- (NSString *)wordInString:(NSString *)string startingAtIndex:(unsigned int)index {
	if (index >= string.length) return nil;
	
	NSScanner *scanner = [NSScanner scannerWithString:[string substringFromIndex:index]];
	NSCharacterSet *wordSet = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789"];
	[scanner setCharactersToBeSkipped:nil];
	NSString *result = nil;
	if ([scanner scanCharactersFromSet:wordSet intoString:&result])
		return result;
	return nil;
}

- (NSString *)htmlFormattedString:(NSString *)string {
	
	// Add link tags to URLs
	string = [self stringWithLinksToURLsWithPrefix:@"http://" inString:string];
	string = [self stringWithLinksToURLsWithPrefix:@"https://" inString:string];
	
	/* 
	// Process text outside of HTML tags.
	NSMutableString *result = [NSMutableString string];
	NSScanner *htmlScanner = [NSScanner scannerWithString:string];
	[htmlScanner setCharactersToBeSkipped:nil];
	NSString *scanned;
	while ([htmlScanner isAtEnd] == NO) {
		if ([htmlScanner scanUpToString:@"<" intoString:&scanned]) {
			// Process text up to tag
			[result appendString:[self stringWithActionLinksInString:scanned]];
		}
		if ([htmlScanner scanUpToString:@">" intoString:&scanned]) {
			// Copy tag whole
			[result appendString:scanned];
		}
		if ([htmlScanner scanString:@">" intoString:nil]) {
			// Close the tag
			[result appendString:@">"];
		}
	}
	 */
	

	// Move to a mutable string
	NSMutableString *result = [NSMutableString stringWithString:string];
	
	// Replace newlines and carriage returns with <br>
	[result replaceOccurrencesOfString:@"\r\n" withString:@"<br>" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\n" withString:@"<br>" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\r" withString:@"<br>" options:0 range:NSMakeRange(0, result.length)];
	
	// Replace tabs with a non-breaking space followed by a normal space
	[result replaceOccurrencesOfString:@"\t" withString:@"&nbsp; " options:0 range:NSMakeRange(0, result.length)];
	
	// Remove NULs
	[result replaceOccurrencesOfString:@"\0" withString:@"" options:0 range:NSMakeRange(0, result.length)];
	
	
	// Process letters outside of HTML tags. Break up long words with soft hyphens and detect @user strings.
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	unsigned int index = 0;
	unsigned int wordLength = 0;
	BOOL isInsideTag = NO;
	unichar c, previousChar = 0;
	while (index < result.length) {
		c = [result characterAtIndex:index];
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
			// Break up words longer than 13 chars
			if (wordLength >= 13) {
				[result replaceCharactersInRange:NSMakeRange(index, 0) withString:@"&shy;"]; // soft hyphen.
				index += 5;
				wordLength = 7; // Reset to 7 so that every 5 chars over 13, it gets a soft hyphen.
			}
			
			NSString *foundWord, *insertHTML;
			
			// @username: action link to User Page
			if (c == '@') {
				foundWord = [self wordInString:result startingAtIndex:index+1];
				if (foundWord.length > 0) {
					insertHTML = [NSString stringWithFormat: @"@<a href='action:user/%@'>%@</a>", foundWord, foundWord];
					[result replaceCharactersInRange: NSMakeRange(index, foundWord.length+1) withString: insertHTML];
					index += insertHTML.length;
					wordLength = 0;
				}
			}
			
			// #hashtag: action link to Search
			if (c == '#' && previousChar != '&') {
				foundWord = [self wordInString:result startingAtIndex:index+1];
				if (foundWord.length > 0) {
					insertHTML = [NSString stringWithFormat: @"<a href='action:search/#%@'>#%@</a>", foundWord, foundWord];
					[result replaceCharactersInRange: NSMakeRange(index, foundWord.length+1) withString: insertHTML];
					index += insertHTML.length;
					wordLength = 0;
				}
			}
			
		}
		
		previousChar = c;
		index++;
	}
	
	return result;
}	

@end
