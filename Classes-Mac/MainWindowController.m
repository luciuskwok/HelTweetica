//
//  MainWindowController.m
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


#import "MainWindowController.h"
#import "UserWindowController.h"
#import "ConversationWindowController.h"
#import "SearchWindowController.h"

#import "HelTweeticaAppDelegate.h"
#import "Twitter.h"
#import "TwitterAccount.h"
#import "TwitterSavedSearch.h"

#import "TwitterLoadListsAction.h"
#import "TwitterLoadSavedSearchesAction.h"


@implementation MainWindowController
@synthesize webView;
@synthesize usersPopUp, timelineSegmentedControl, listsPopUp, searchField, searchMenu;
@synthesize htmlController, lists, subscriptions, currentSheet;


- (id)init {
	self = [super initWithWindowNibName:@"MainWindow"];
	if (self) {
		appDelegate = [NSApp delegate];
		
		// Timeline HTML Controller generates the HTML from a timeline
		self.htmlController = [[[TimelineHTMLController alloc] init] autorelease];
		htmlController.twitter = appDelegate.twitter;
		htmlController.delegate = self;
		htmlController.useRewriteHTMLTimer = YES;
		
		// Listen for changes to Twitter state data
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(savedSearchesDidChange:) name:@"savedSearchesDidChange" object:nil];
		[nc addObserver:self selector:@selector(accountsDidChange:) name:@"accountsDidChange" object:nil];
		[nc addObserver:self selector:@selector(timelineDidFinishLoading:) name:TwitterTimelineDidFinishLoadingNotification object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[lists release];
	[subscriptions release];
	
	[currentSheet release];
	
	[super dealloc];
}

- (void)setAccount:(TwitterAccount *)anAccount {
	htmlController.account = anAccount;
	self.lists = anAccount.lists;
	self.subscriptions = anAccount.listSubscriptions;
}

- (TwitterAccount *)accountWithScreenName:(NSString*)screenName {
	appDelegate = [NSApp delegate];
	
	TwitterAccount *account = [appDelegate.twitter accountWithScreenName:screenName];
	if (account == nil) {
		if (htmlController.twitter.accounts.count > 0) 
			account = [htmlController.twitter.accounts objectAtIndex:0];
	}
	return account;
}	

#pragma mark NSCoding for saving app state

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [self init];
	if (self) {
		[self setAccount: [self accountWithScreenName: [aDecoder decodeObjectForKey:@"accountScreenName"]]];
		[self.window setFrameAutosaveName: [aDecoder decodeObjectForKey:@"windowFrameAutosaveName"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:htmlController.account.screenName forKey:@"accountScreenName"];
	[aCoder encodeObject:[self.window frameAutosaveName ] forKey:@"windowFrameAutosaveName"];
}

#pragma mark Timelines

- (void)updateTimelineSegmentedControl {
	if (timelineSegmentedControl == nil) 
		return;
	
	NSArray *images = [NSArray arrayWithObjects:@"mac-toolbar-home", @"mac-toolbar-mentions", @"mac-toolbar-direct", @"mac-toolbar-star", nil];
	if ([timelineSegmentedControl segmentCount] != images.count) return;
	NSString *imageName;
	BOOL unread[3];
	unread[0] = [htmlController.account hasUnreadInHomeTimeline];
	unread[1] = [htmlController.account hasUnreadInMentions];
	unread[2] = [htmlController.account hasUnreadInDirectMessages];
	
	for (int index = 0; index < images.count; index++) {
		imageName = [images objectAtIndex:index];
		if ([timelineSegmentedControl isSelectedForSegment:index]) {
			// Use white version for selected segments.
			imageName = [imageName stringByAppendingString:@"-alt"];
		} else {
			// Use badged version for unread items.
			if (index <= 2) {
				if (unread[index]) {
					imageName = [imageName stringByAppendingString:@"-badged"];
				}
			}
		}
		imageName = [imageName stringByAppendingString:@".png"];
		[timelineSegmentedControl setImage:[NSImage imageNamed:imageName] forSegment:index];
	}

	[self reloadUsersMenu];
}

- (IBAction)selectTimelineWithSegmentedControl:(id)sender {
	int index = [sender selectedSegment];
	switch (index) {
		case 0:
			[self homeTimeline:nil];
			break;
		case 1:
			[self mentions:nil];
			break;
		case 2:
			[self directMessages:nil];
			break;
		case 3:
			[self favorites:nil];
			break;
		default:
			break;
	}
}

- (IBAction)homeTimeline:(id)sender {
	htmlController.customPageTitle = nil;
	[htmlController selectHomeTimeline];
	if (htmlController.webViewHasValidHTML)
		[self.webView scrollToTop];
}

- (IBAction)mentions:(id)sender {
	if (htmlController.account.screenName) {
		htmlController.customPageTitle = [NSString stringWithFormat:@"@%@ <b>Mentions</b>", htmlController.account.screenName];
	} else {
		htmlController.customPageTitle = @"Your <b>Mentions</b>";
	}

	[htmlController selectMentionsTimeline];
	if (htmlController.webViewHasValidHTML)
		[self.webView scrollToTop];
}

- (IBAction)directMessages:(id)sender {
	htmlController.customPageTitle = @"<b>Direct</b> Messages";
	[htmlController selectDirectMessageTimeline];
	if (htmlController.webViewHasValidHTML)
		[self.webView scrollToTop];
}

- (IBAction)favorites:(id)sender {
	htmlController.customPageTitle = @"Your <b>Favorites</b>";
	[htmlController selectFavoritesTimeline];
	if (htmlController.webViewHasValidHTML)
		[self.webView scrollToTop];
}

- (IBAction)refresh:(id)sender {
	if (htmlController.webViewHasValidHTML)
		[self.webView scrollToTop];
	
	// If showing a list or favorites or search or something that isn't automatically refreshed by the Twitter class, refresh just that timeline.
	[htmlController refresh];
}

#pragma mark Refresh timer

- (void)scheduleRefreshTimer {
	[refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(fireRefreshTimer:) userInfo:nil repeats:NO];
}

- (void)invalidateRefreshTimer {
	[refreshTimer invalidate];
	refreshTimer = nil;
}

- (void)fireRefreshTimer:(NSTimer *)timer {
	[self updateTimelineSegmentedControl];
	[self reloadUsersMenu];
	refreshTimer = nil;
}

- (void)timelineDidFinishLoading:(NSNotification *)notification {
	[self scheduleRefreshTimer];
}

#pragma mark Users

- (void)reloadUsersMenu {
	const int kUsersMenuPresetItems = 8;
	
	if (usersPopUp == nil) 
		return;
	
	// Remove all items after separator and insert screen names of all accounts.
	while (usersPopUp.menu.numberOfItems > kUsersMenuPresetItems) {
		[usersPopUp.menu removeItemAtIndex:kUsersMenuPresetItems];
	}
	
	// Insert
	for (TwitterAccount *account  in htmlController.twitter.accounts) {
		// Check for unread mentions and direct messages.
		NSString *title = account.screenName;
		if ([account hasUnreadInHomeTimeline]) {
			title = [title stringByAppendingString:@" ⌂"];
		} 
		if ([account hasUnreadInMentions]) {
			title = [title stringByAppendingString:@" ﹫"];
		} 
		if ([account hasUnreadInDirectMessages]) {
			title = [title stringByAppendingString:@" ✉"];
		}
		
		// Create the menu item.
		NSMenuItem *item = [self menuItemWithTitle:title action:@selector(selectAccount:) representedObject:account indentationLevel:1];
		
		// Put checkmark next to current account
		if (account == htmlController.account) {
			[item setState:NSOnState];
		}
		
		// Profile image
		[item setImage:[account profileImage16px]];
		
		[usersPopUp.menu addItem:item];
	}
}

- (void)accountsDidChange:(NSNotification*)notification {
	[self reloadUsersMenu];
}

- (IBAction)goToUser:(id)sender {
	[self showUserPage:nil];
}

- (IBAction)myProfile:(id)sender {
	[self showUserPage:htmlController.account.screenName];
}

- (IBAction)addAccount:(id)sender {
	[self showLoginWithScreenName:nil];
}

- (IBAction)editAccounts:(id)sender {
	[appDelegate showPreferences:sender];
}

- (void)didLoginToAccount:(TwitterAccount*)anAccount {
	htmlController.account = anAccount;
	
	// Set window title to account name
	[[self window] setTitle:anAccount.screenName];
	
	if (htmlController.webViewHasValidHTML)
		[self.webView scrollToTop];
	
	htmlController.customPageTitle = nil;
	[htmlController selectHomeTimeline];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: anAccount.screenName forKey: @"currentAccount"];
	
	[self reloadUsersMenu];
	[self reloadListsMenu];
	[self reloadSearchMenu];
	
	// Start loading lists and saved searches
	[self loadListsOfUser:nil];
	[self loadSavedSearches];
}

- (void)loginFailedWithAccount:(TwitterAccount*)anAccount {
	[self showAlertWithTitle:@"Login failed." message:@"The username or password was not correct."];
}

- (IBAction)selectAccount:(id)sender {
	TwitterAccount *account = [sender representedObject];
	if (account) {
		// Check if logged in, else ask for password again
		if (account.xAuthToken) {
			[self didLoginToAccount:account];
		} else {
			[self showLoginWithScreenName:account.screenName];
		}
	}
}

- (void)showLoginWithScreenName:(NSString*)screenName {
	AddAccount* sheet = [[[AddAccount alloc] initWithTwitter:htmlController.twitter] autorelease];
	sheet.screenName = screenName;
	sheet.delegate = self;
	[sheet askInWindow: [self window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)];
	self.currentSheet = sheet;
}

#pragma mark Lists

- (void)reloadListsMenu {
	NSMenuItem *menuItem;
	NSString *menuTitle;
	const int kListsMenuPresetItems = 1;
	
	// Remove all items.
	while (listsPopUp.menu.numberOfItems > kListsMenuPresetItems) {
		[listsPopUp.menu removeItemAtIndex:kListsMenuPresetItems];
	}
	
	// Insert lists
	if (lists.count > 0) {
		menuTitle = NSLocalizedString (@"Lists", @"menu");
		menuItem = [self menuItemWithTitle:menuTitle action:@selector(disabledMenuItem:) representedObject:nil indentationLevel:0];
		[listsPopUp.menu addItem:menuItem];
			
		for (TwitterList *list in lists) {
			menuItem = [self menuItemWithTitle:[list.fullName substringFromIndex:1] action:@selector(selectList:) representedObject:list indentationLevel:1];
			[listsPopUp.menu addItem:menuItem];
		}
	}
	
	// Separator
	if (lists.count > 0 && subscriptions.count > 0) {
		[listsPopUp.menu addItem:[NSMenuItem separatorItem]];
	}
	
	// Insert subscriptions
	if (subscriptions.count > 0) {
		menuTitle = NSLocalizedString (@"List Subscriptions", @"menu");
		menuItem = [self menuItemWithTitle:menuTitle action:@selector(disabledMenuItem:) representedObject:nil indentationLevel:0];
		[listsPopUp.menu addItem:menuItem];
		
		for (TwitterList *list in subscriptions) {
			menuItem = [self menuItemWithTitle:[list.fullName substringFromIndex:1] action:@selector(selectList:) representedObject:list indentationLevel:1];
			[listsPopUp.menu addItem:menuItem];
		}
	}
	
	// Empty menu
	if (lists.count == 0 && subscriptions.count == 0) {
		[listsPopUp.menu addItemWithTitle:@"No lists" action:@selector(disabledMenuItem:) keyEquivalent:@""];
	}
	
}

- (IBAction)selectList:(id)sender {
	TwitterList *aList = [sender representedObject];
	[htmlController loadList:aList];
}

- (void)loadListsOfUser:(NSString*)userOrNil {
	// Load Lists from Twitter, if logged in.
	if (htmlController.account.xAuthToken) {
	// Load user's own lists.
		TwitterLoadListsAction *listsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:NO] autorelease];
		listsAction.completionTarget= self;
		listsAction.completionAction = @selector(didLoadLists:);
		[htmlController.twitter startTwitterAction:listsAction withAccount:htmlController.account];
		
		// Load lists that user subscribes to.
		TwitterLoadListsAction *subscriptionsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:YES] autorelease];
		subscriptionsAction.completionTarget= self;
		subscriptionsAction.completionAction = @selector(didLoadListSubscriptions:);
		[htmlController.twitter startTwitterAction:subscriptionsAction withAccount:htmlController.account];
	}
}

- (void)didLoadLists:(TwitterLoadListsAction *)action {
	// Keep the old list objects that match new ones because it caches the status updates
	[htmlController.account synchronizeExisting:lists withNew:action.lists];
	[self reloadListsMenu];
}

- (void)didLoadListSubscriptions:(TwitterLoadListsAction *)action {
	[htmlController.account synchronizeExisting: subscriptions withNew:action.lists];
	[self reloadListsMenu];
}


#pragma mark Search

- (void)reloadSearchMenu {
	const int kSavedSearchesItemTag = 2000;
	NSMenuItem *menuItem;
	int savedSearchesItemIndex = [searchMenu indexOfItemWithTag:kSavedSearchesItemTag];
	if (savedSearchesItemIndex < 0) return;
	
	// Remove all item after the saved searches tag
	while (searchMenu.numberOfItems > savedSearchesItemIndex + 1) {
		[searchMenu removeItemAtIndex:savedSearchesItemIndex + 1];
	}
	
	// Insert saved searches
	for (TwitterSavedSearch *query in htmlController.account.savedSearches) {
		menuItem = [self menuItemWithTitle:query.query action:@selector(search:) representedObject:query.query indentationLevel:1];
		[searchMenu addItem:menuItem];
	}
	
	// Empty menu
	if (htmlController.account.savedSearches.count == 0) {
		menuItem = [self menuItemWithTitle:@"No saved searches" action:@selector(disabledMenuItem:) representedObject:nil indentationLevel:1];
		[searchMenu addItem:menuItem];
	}
	
	// Update the menu in the search field
	[[searchField cell] setSearchMenuTemplate: searchMenu];
}

- (void)savedSearchesDidChange:(NSNotification*)notification {
	[self reloadSearchMenu];
}

- (IBAction)search:(id)sender {
	NSString *query = nil;
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		query = [sender representedObject];
	} else if ([sender isKindOfClass:[NSControl class]]) {
		query = [sender stringValue];
	}
	if (query.length > 0) {
		[self searchForQuery:query];
	}
}

- (void)searchForQuery:(NSString*)aQuery {
	// Put the query in the search box
	if ([aQuery isEqualToString: [searchField stringValue]] == NO) {
		[searchField setStringValue:aQuery];
	}
	
	// Create and show the Search Results window
	SearchWindowController *controller = [[[SearchWindowController alloc] initWithQuery:aQuery] autorelease];
	[controller setAccount:htmlController.account];
	[controller showWindow:nil];
	[appDelegate addWindowController:controller];
}

- (void)loadSavedSearches {
	// Load Saved Searches from Twitter, if logged in.
	if (htmlController.account.xAuthToken) {
		TwitterLoadSavedSearchesAction *action = [[[TwitterLoadSavedSearchesAction alloc] init] autorelease];
		action.completionTarget= self;
		action.completionAction = @selector(didLoadSavedSearches:);
		[htmlController.twitter startTwitterAction:action withAccount:htmlController.account];
	}
}

- (void)didLoadSavedSearches:(TwitterLoadSavedSearchesAction *)action {
	htmlController.account.savedSearches = action.savedSearches;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"savedSearchesDidChange" object:self];
}

#pragma mark Compose

- (Compose *)standardComposeController {
	Compose* compose = [[[Compose alloc] initWithTwitter:htmlController.twitter account:htmlController.account] autorelease];
	compose.delegate = self;
	return compose;
}

- (IBAction)compose:(id)sender {
	Compose* compose = [self standardComposeController];
	[compose showWindow:sender];
	[appDelegate addWindowController:compose];
}

- (void)retweet:(NSNumber*)identifier {
	TwitterStatusUpdate *message = [htmlController.twitter statusUpdateWithIdentifier: identifier];
	if (message == nil) return;
	
	Compose* compose = [self standardComposeController];
	if (message != nil) {
		// Replace current message content with retweet. In a future version, save the existing tweet as a draft and make a new tweet with this text.
		compose.messageContent = [NSString stringWithFormat:@"RT @%@: %@", message.userScreenName, message.text];
		compose.originalRetweetContent = compose.messageContent;
		compose.inReplyTo = identifier;
	}
	
	[compose showWindow:nil];
	[appDelegate addWindowController:compose];
}

- (void)replyToMessage: (NSNumber*)identifier {
	Compose* compose = [self standardComposeController];
	TwitterStatusUpdate *message = [htmlController.twitter statusUpdateWithIdentifier: identifier];
	
	// Insert @username in beginning of message. This preserves any other people being replied to.
	if (message != nil) {
		NSString *replyUsername = message.userScreenName;
		if (compose.messageContent != nil) {
			compose.messageContent = [NSString stringWithFormat:@"@%@ %@", replyUsername, compose.messageContent];
		} else {
			compose.messageContent = [NSString stringWithFormat:@"@%@ ", replyUsername];
		}
		compose.inReplyTo = identifier;
		compose.originalRetweetContent = nil;
		compose.newStyleRetweet = NO;
	}
	
	[compose showWindow:nil];
	[appDelegate addWindowController:compose];
}

- (void)directMessageWithScreenName:(NSString*)screenName {
	Compose* compose = [self standardComposeController];
	
	if (screenName != nil) {
		compose.originalRetweetContent = nil;
		compose.directMessageScreenname = screenName;
	}
	
	[compose showWindow:nil];
	[appDelegate addWindowController:compose];
}

- (void) composeDidFinish:(Compose*)aCompose {
	[self refresh:nil];
}

#pragma mark Delete

- (void)deleteStatusUpdate:(NSNumber *)identifier {
	// Alert that delete is permanent and cannot be undone.
	if (self.currentSheet == nil) { // Don't show another alert if one is already up.
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"button")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"button")];
		[alert setMessageText:NSLocalizedString(@"Delete Tweet?", @"title")];
		[alert setInformativeText:NSLocalizedString(@"This tweet will be deleted permanently and cannot be undone.", @"message")];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(didEndDeleteSheet:returnCode:contextInfo:) contextInfo:[identifier retain]];
		self.currentSheet = alert;
	}
}

- (void)didEndDeleteSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	self.currentSheet = nil;
	if (returnCode == NSAlertFirstButtonReturn) { // Delete
		NSNumber *identifier = contextInfo;
		[htmlController deleteStatusUpdate:identifier];
		[identifier release];
	}
}



#pragma mark Misc menu items

- (IBAction)disabledMenuItem:(id)sender {
	// Do nothing
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	return (menuItem.action != @selector(disabledMenuItem:));
}

- (NSMenuItem*)menuItemWithTitle:(NSString *)title action:(SEL)action representedObject:(id)representedObject indentationLevel:(int)indentationLevel {
	NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
	menuItem.title = title;
	menuItem.target = self;
	menuItem.action = action;
	menuItem.representedObject = representedObject;
	menuItem.indentationLevel = indentationLevel;
	return menuItem;
}	

#pragma mark Web actions

- (void) showUserPage:(NSString*)screenName {
	// Create and show the user window
	UserWindowController *controller = [[[UserWindowController alloc] initWithScreenName:screenName account:htmlController.account] autorelease];
	[controller showWindow:nil];
	[appDelegate addWindowController:controller];
}

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// Create and show the Conversation window
	ConversationWindowController *controller = [[[ConversationWindowController alloc] init] autorelease];
	[controller setAccount:htmlController.account];
	controller.messageIdentifier = identifier;
	[controller showWindow:nil];
	[appDelegate addWindowController:controller];
}

#pragma mark WebView policy delegate

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id)listener {
	
	NSString *scheme = [[request URL] scheme];
	
	// Handle Actions ourselves
	if ([scheme isEqualToString:@"action"]) {
		NSString *actionName = [[request URL] resourceSpecifier];
		NSNumber *messageIdentifier = [htmlController number64WithString:[actionName lastPathComponent]];
		
		if ([actionName hasPrefix:@"login"]) { // Log in
			[self addAccount:nil];
		} else if ([actionName hasPrefix:@"delete"]) { // Delete status update
			[self deleteStatusUpdate:messageIdentifier];
		} else if ([actionName hasPrefix:@"dm"]) { // Direct message the sender
			[self directMessageWithScreenName:[actionName lastPathComponent]];
		} else if ([actionName hasPrefix:@"retweet"]) { // Retweet status update
			[self retweet: messageIdentifier];
		} else if ([actionName hasPrefix:@"reply"]) { // Public reply to the sender
			[self replyToMessage:messageIdentifier];
		} else if ([actionName hasPrefix:@"user"]) { // Show user page
			[self showUserPage:[actionName lastPathComponent]];
		} else if ([actionName hasPrefix:@"search"]) { // Show search page
			[self searchForQuery:[[actionName lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		} else if ([actionName hasPrefix:@"conversation"]) { // Show more info on the tweet
			[self showConversationWithMessageIdentifier:messageIdentifier];
		} else {
			// handleWebAction: returns a BOOL to indicate whether or not it handled the action, but it's not needed here.
			[htmlController handleWebAction:actionName];
		}
		[listener ignore];
	}
	
	// Open links in default browser
	else if ([scheme hasPrefix:@"http"]) {
		[[NSWorkspace sharedWorkspace] openURL: [request URL]];
		[listener ignore];
	} else {
		[listener use];
	}
}

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
	//[appDelegate incrementNetworkActionCount];
	htmlController.webViewHasValidHTML = YES;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	//[appDelegate decrementNetworkActionCount];
	htmlController.webViewHasValidHTML = YES;
	
	if (htmlController.isLoading == NO) {
		[htmlController hideTwitterStatus];
	}
}

#pragma mark TimelineHTMLController delegate

- (void)didSelectTimeline:(TwitterTimeline *)timeline {
	int index = -1;
	if (timeline == htmlController.account.homeTimeline) {
		index = 0;
	} else if (timeline == htmlController.account.mentions) {
		index = 1;
	} else if (timeline == htmlController.account.directMessages) {
		index = 2;
	} else if (timeline == htmlController.account.favorites) {
		index = 3;
	}
	if (index >= 0) {
		[timelineSegmentedControl setSelectedSegment:index];
	} else {
		// Deselect
		index = [timelineSegmentedControl selectedSegment];
		if (index >= 0)
			[timelineSegmentedControl setSelected:NO forSegment:index];
	}
	[self updateTimelineSegmentedControl];
}

#pragma mark Window 

- (void)windowDidLoad {
	// Set up additional web view preferences that aren't set up in IB.
	[self.webView setPreferencesIdentifier:@"HelTweeticaWebPrefs"];
	WebPreferences *prefs = self.webView.preferences;
	[prefs setJavaEnabled:NO];
	[prefs setJavaScriptEnabled:YES];
	[prefs setPlugInsEnabled:NO];
	[prefs setUsesPageCache:NO];
	[prefs setCacheModel:WebCacheModelDocumentViewer];
	[prefs setPrivateBrowsingEnabled:YES];
	[webView setMaintainsBackForwardList:NO]; 
	
	htmlController.webView = self.webView;
	[htmlController selectHomeTimeline];
	[htmlController loadWebView];
	
	[self updateTimelineSegmentedControl];
	
	// Set window title to account name
	NSString *screenName = htmlController.account.screenName;
	if (screenName) 
		[[self window] setTitle:screenName];
	
	[self reloadUsersMenu];
	[self reloadListsMenu];
	[self reloadSearchMenu];
}	

- (BOOL)windowShouldClose:(id)sender {
	[webView setFrameLoadDelegate:nil];
	[webView close];
	self.webView = nil;
	
	htmlController.useRewriteHTMLTimer = NO;
	[htmlController invalidateRewriteHTMLTimer];
	htmlController.delegate = nil;
	self.htmlController = nil;
	
	return YES;
}

#pragma mark Alert

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	if (self.currentSheet == nil) { // Don't show another alert if one is already up.
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:aTitle];
		[alert setInformativeText:aMessage];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
		self.currentSheet = alert;
	}
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	self.currentSheet = nil;
}

#pragma mark Twitter status 

- (IBAction)showTwitterStatus:(id)sender {
	[htmlController showTwitterStatusWithString:nil];
}

- (IBAction)hideTwitterStatus:(id)sender {
	[htmlController hideTwitterStatus];
}


@end
