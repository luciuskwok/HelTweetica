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

#import "TwitterFavoriteAction.h"
#import "TwitterDeleteAction.h"

#import "TwitterLoadDirectMessagesAction.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"

#import "TwitterDirectMessageConversation.h"



// Constants
#ifdef TARGET_PROJECT_MAC
const int kDefaultMaxTweetsShown = 400;
#else
const int kDefaultMaxTweetsShown = 200;
#endif
static NSString *kTimelineIdentifier = @"Timeline";
static NSString *kMentionsIdentifier = @"Mentions";
static NSString *kDirectMessagesIdentifier = @"Direct";
static NSString *kFavoritesIdentifier = @"Favorites";



@implementation TimelineHTMLController
@synthesize webView, twitter, account, timeline, messages, actions;
@synthesize maxTweetsShown, webViewHasValidHTML, isLoading, noInternetConnection, suppressNetworkErrorAlerts;
@synthesize customPageTitle, customTabName;
@synthesize delegate;


- (id)init {
	self = [super init];
	if (self) {
		
		// Load the HTML templates.
		directMessageRowTemplate = [[self loadHTMLTemplate:@"dm-row-template"] retain];
		directMessageRowSectionOpenTemplate = [[self loadHTMLTemplate:@"dm-row-section-open"] retain];
		directMessageRowSectionCloseHTML = [[self loadHTMLTemplate:@"dm-row-section-close"] retain];
		tweetRowTemplate = [[self loadHTMLTemplate:@"tweet-row-template"] retain];
		tweetGapRowTemplate = [[self loadHTMLTemplate:@"load-gap-template"] retain];
		
		// Loading template
		loadingHTML = [@"<div class='status'><img class='status_spinner_image' src='spinner.gif'> Loading...</div>"retain];

		// Misc
		isLoading = YES;
		maxTweetsShown = kDefaultMaxTweetsShown; 
		self.actions = [NSMutableArray array]; // List of currently active network connections
		
	}
	return self;
}

- (void)dealloc {
	[self invalidateRefreshTimer];
	
	[webView release];
	
	[twitter release];
	[account release];
	[timeline release];
	[messages release];
	[actions release];
	
	[directMessageRowTemplate release];
	[directMessageRowSectionOpenTemplate release];
	[directMessageRowSectionCloseHTML release];
	
	[tweetRowTemplate release];
	[tweetGapRowTemplate release];
	[loadingHTML release];
	
	[customPageTitle release];
	[customTabName release];
	
	[super dealloc];
}

#pragma mark Timeline selection

- (void)updateForNewTimeline {
	// Call this after selecting a different timeline.
	suppressNetworkErrorAlerts = NO;
	timeline.delegate = self;
	self.messages = [timeline messagesWithLimit:maxTweetsShown];
	[self rewriteTweetArea];
	
	// Notify delegate that a different timeline was selected.
	if ([delegate respondsToSelector:@selector(didSelectTimeline:)])
		[delegate didSelectTimeline:timeline];
	
	// Schedule a refresh instead of loading right away.
	[self scheduleRefreshTimer];
}

- (void)selectHomeTimeline {
	self.customTabName = kTimelineIdentifier;
	self.timeline = account.homeTimeline;
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/home_timeline"] autorelease];
	[self updateForNewTimeline];
}

- (void)selectMentionsTimeline {
	self.customTabName = kMentionsIdentifier;
	self.timeline = account.mentions;
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/mentions"] autorelease];
	[self updateForNewTimeline];
}

- (void)selectDirectMessageTimeline {
	self.customTabName = kDirectMessagesIdentifier;
	self.timeline = account.directMessages;
	self.timeline.loadAction = nil; // TwitterDirectMessageTimeline sets its own load action.
	[self updateForNewTimeline];
}

- (void)selectFavoritesTimeline {
	self.customTabName = kFavoritesIdentifier;
	self.timeline = account.favorites;
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	// Favorites always loads 20 per page. Cannot change the count.
	[self updateForNewTimeline];
}


#pragma mark Loading

- (void)loadTimeline:(TwitterTimeline*)aTimeline {
	self.timeline = aTimeline;
	timeline.delegate = self;
	self.messages = [timeline messagesWithLimit:maxTweetsShown];

	if (noInternetConnection == NO) {
		isLoading = YES;
		if (timeline == account.favorites) {
			// Reload messages ignoring what's already local in case there are gaps in our version of the timeline.
			[timeline reloadAll];
		} else {
			[timeline reloadNewer];
		}
	}
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

- (BOOL)array:(NSArray *)arrayA containsObjectsNotInArray:(NSArray *)arrayB {
	for (id item in arrayA) {
		if ([arrayB containsObject:item] == NO) 
			return YES;
	}
	return NO;
}

- (void) timeline:(TwitterTimeline *)aTimeline didLoadWithAction:(TwitterAction *)action {
	isLoading = NO;
	
	if ([action isKindOfClass:[TwitterLoadTimelineAction class]]) {
		TwitterLoadTimelineAction *statusUpdateAction = (TwitterLoadTimelineAction *)action;
		
		// Only update if there are messages not already in the displayed messages.
		if ([self array:statusUpdateAction.loadedMessages containsObjectsNotInArray:messages]) {
			// Twitter cache.
			[twitter addStatusUpdates:statusUpdateAction.loadedMessages replaceExisting:YES];
			[twitter addStatusUpdates:statusUpdateAction.retweetedMessages replaceExisting:YES];
			[twitter addOrReplaceUsers:statusUpdateAction.users];

			// Ignore gaps for own RTs.
			BOOL updateGap = ([action.twitterMethod isEqualToString:@"statuses/retweeted_by_me"] == NO);
			[aTimeline addMessages:statusUpdateAction.loadedMessages updateGap:updateGap];

			if (timeline == aTimeline) {
				// To be safe, only update Favorites if the same timeline is still selected.
				[account addFavorites:statusUpdateAction.favoriteMessages];
			}
		}
	} else if ([action isKindOfClass:[TwitterLoadDirectMessagesAction class]]) {
		TwitterLoadDirectMessagesAction *directMessagesAction = (TwitterLoadDirectMessagesAction *)action;
		
		if ([self array:directMessagesAction.loadedMessages containsObjectsNotInArray:messages]) {
			// Twitter cache.
			[twitter addDirectMessages:directMessagesAction.loadedMessages];
			[twitter addOrReplaceUsers:directMessagesAction.users];

			// Timeline
			TwitterDirectMessageTimeline *dmTimeline = (TwitterDirectMessageTimeline *)aTimeline;
			[dmTimeline addMessages:directMessagesAction.loadedMessages sent:([action.twitterMethod hasSuffix:@"sent"])];
		}
	}

	// Load latest messages.
	if (timeline == aTimeline) {
		self.messages = [timeline messagesWithLimit: maxTweetsShown];
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
	listTimeline.loadAction.countKey = @"per_page";
	suppressNetworkErrorAlerts = NO;
	
	// Prepare database.
	[list setDatabase:twitter.database];
	
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
	if (action == nil) return;
	
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

#pragma mark Favorite status update

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
	
	// Change the star to a spinner.
	NSString *element = [NSString stringWithFormat:@"star-%@", [message.identifier stringValue]];
	NSString *html = @"<img src='fave-spinner.gif'>";
	[self.webView setDocumentElement:element innerHTML:html];
	
}

- (void)didFave:(TwitterFavoriteAction *)action {
	TwitterStatusUpdate *message = [action message];
	if (action.success == NO) return;
	BOOL isFave = !action.destroy;
	
	// Change the display of the star next to tweet in root view
	NSString *element = [NSString stringWithFormat:@"star-%@", [message.identifier stringValue]];
	NSString *html = isFave ? @"<img src='action-star-on.png'>" : @"<img src='action-star.png'>";
	[self.webView setDocumentElement:element innerHTML:html];
	
	// Remove from favorites timeline
	if (isFave) {
		[account addFavorites:[NSArray arrayWithObject:message]];
	} else {
		[account removeFavorite:message.identifier];
	}
}

#pragma mark Delete status update

- (void)deleteStatusUpdate:(NSNumber *)identifier {
	// Change the trash can to a spinner.
	NSString *element = [NSString stringWithFormat:@"trash-%@", [identifier stringValue]];
	NSString *html = @"<img src='fave-spinner.gif'>";
	[self.webView setDocumentElement:element innerHTML:html];

	TwitterDeleteAction *action = [[[TwitterDeleteAction alloc] initWithMessageIdentifier:identifier] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didDeleteStatusUpdate:);
	[self startTwitterAction:action];
}

- (void)didDeleteStatusUpdate:(TwitterDeleteAction *)action {
	[twitter deleteStatusUpdate:action.identifier];
	self.messages = [timeline messagesWithLimit:maxTweetsShown];
	[self rewriteTweetArea];
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
	} else if ([action isEqualToString:kDirectMessagesIdentifier]) { // Mentions
		self.customPageTitle = nil; // Reset the custom page title.
		[self selectDirectMessageTimeline];
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
			//[self rewriteTweetArea];
		}
	} else {
		// If there are actions already pending, reschedule refresh 
		refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
	}
}

#pragma mark HTML

- (NSString *)htmlWithTemplate:(NSString *)template substitutions:(NSDictionary *)substitutions {
	if (template == nil) return nil;
	
	// Use scanner to replace curly-bracketed variables with values
	NSScanner *scanner = [NSScanner scannerWithString:template];
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
	
	return tweetRowHTML;
}

- (NSString *)htmlWithStatusUpdate:(TwitterStatusUpdate *)statusUpdate rowIndex:(int)rowIndex {
	// Skip rows with invalid identifiers.
	if ([statusUpdate.identifier longLongValue] < 1000) return @"";
	
	BOOL lastRow = (rowIndex >= maxTweetsShown - 1 || rowIndex >= messages.count - 1);
	NSMutableDictionary *substitutions = [NSMutableDictionary dictionary];
	NSMutableString *gapRowHTML = nil;
	
	// Append "Load gap" row if needed
	BOOL gap = [timeline hasGapAfter:statusUpdate.identifier];
	NSString *messageIdentifier = [statusUpdate.identifier stringValue];
	if ((gap == YES) && (lastRow == NO)) {
		gapRowHTML = [NSMutableString stringWithString:tweetGapRowTemplate];
		[gapRowHTML replaceOccurrencesOfString:@"{gapIdentifier}" withString:messageIdentifier options:0 range:NSMakeRange(0, gapRowHTML.length)];
	}
	
	// Special handling for new-style retweets.
	if ([statusUpdate.retweetedStatusIdentifier longLongValue] != 0) {
		[substitutions setObject:@"<img src='retweet.png'>" forKey:@"retweetIcon"];
		if (statusUpdate.userScreenName) 
			[substitutions setObject:statusUpdate.userScreenName forKey:@"retweetedBy"];
		statusUpdate = [twitter statusUpdateWithIdentifier:statusUpdate.retweetedStatusIdentifier];
	}

	// Row style
	NSString *rowStyle = [self styleForStatusUpdate:statusUpdate rowIndex:rowIndex];
	if (rowStyle != nil) 
		[substitutions setObject:rowStyle forKey:@"tweetRowStyle"];
						  
	// Favorites
	if ([account messageIsFavorite:statusUpdate.identifier]) 
		[substitutions setObject:@"-on" forKey:@"faveImageSuffix"];
	
	// Own tweets.
	if ([statusUpdate.userIdentifier isEqualToNumber:account.identifier]) {
		// Show delete action but hide reply, dm, and retweet buttons.
		[substitutions setObject:@"YES" forKey:@"ownActions"];
	} else {
		// Always show action buttons on right side of page.
		[substitutions setObject:@"YES" forKey:@"actions"];
	}
	
	// Add values from status update.
	[substitutions addEntriesFromDictionary:[statusUpdate htmlSubstitutions]];
	
	// Load template and apply substitutions.
	NSString *html = [self htmlWithTemplate:tweetRowTemplate substitutions:substitutions];
	if (gapRowHTML != nil) 
		html = [html stringByAppendingString:gapRowHTML];
	
	return html;
}

- (NSString *)styleForStatusUpdate:(TwitterStatusUpdate *)statusUpdate rowIndex:(int)rowIndex {
	NSString *style = nil;
	
	// Mentions
	NSRange found = [statusUpdate.text rangeOfString:[NSString stringWithFormat:@"@%@", account.screenName] options:NSCaseInsensitiveSearch];
	if (found.location != NSNotFound)
		style = @"mention_tweet_row";
	
	// Own tweets
	if ([statusUpdate.userIdentifier isEqualToNumber:account.identifier] || [statusUpdate.userScreenName isEqualToString:account.screenName])
		style = @"self_tweet_row";

	return style;
}

- (NSString *)htmlWithDirectMessageConversation:(TwitterDirectMessageConversation *)conversation rowIndex:(int)rowIndex {
	// Each row in the messages array corresponds to one conversation with one user. Each conversation has a subarray of direct messages, sorted by date, newest first. 

	NSMutableString *html = [NSMutableString string];
	
	// Open the row and substitute the user screenName and profileImageURL in the template.
	NSMutableDictionary *substitutions = [NSMutableDictionary dictionary];
	TwitterUser *user = [twitter userWithIdentifier:conversation.user];
	[substitutions setObject:user.screenName forKey:@"screenName"];
	[substitutions setObject:user.profileImageURL forKey:@"profileImageURL"];
	[html appendString:[self htmlWithTemplate:directMessageRowSectionOpenTemplate substitutions:substitutions]];
	
	// Loop through each message
	for (TwitterDirectMessage *message in conversation.messages) {
		[html appendString:[self htmlWithTemplate:directMessageRowTemplate substitutions:[message htmlSubstitutions]]];
	}
	
	// Close the row.
	[html appendString:directMessageRowSectionCloseHTML];
	
	return html;
}

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

	// Rows of status updates or direct messages.
	id rowItem;
	for (int index=0; index<messages.count; index++) {
		rowItem = [messages objectAtIndex:index];
		if ([rowItem isKindOfClass:[TwitterStatusUpdate class]]) {
			[html appendString:[self htmlWithStatusUpdate:rowItem rowIndex:index]];
		} else if ([rowItem isKindOfClass:[TwitterDirectMessageConversation class]]) {
			[html appendString:[self htmlWithDirectMessageConversation:rowItem rowIndex:index]];
		}
	}
	
	[html appendString:@"</div> "]; // Close tweet_table
	
	// Footer
	[html appendString:@"<div id='footer'>"];
	[html appendString:[self tweetAreaFooterHTML]];
	[html appendString:@"</div> "]; // Close footer
	
	return html;
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


@end
