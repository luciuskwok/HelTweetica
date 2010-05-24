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
#import "HelTweeticaAppDelegate.h"

#import "Twitter.h"
#import "TwitterAccount.h"

#import "TwitterLoadListsAction.h"


@implementation MainWindowController
@synthesize webView;
@synthesize usersPopUp, timelineSegmentedControl, listsPopUp, searchField;
@synthesize HTMLController, lists, subscriptions, currentSheet;


- (id)initWithTwitter:(Twitter*)aTwitter account:(TwitterAccount*)account {
	self = [super initWithWindowNibName:@"MainWindow"];
	if (self) {
		appDelegate = [NSApp delegate];
		
		// Timeline HTML Controller generates the HTML from a timeline
		self.HTMLController = [[[TimelineHTMLController alloc] init] autorelease];
		HTMLController.twitter = aTwitter;
		HTMLController.delegate = self;
		HTMLController.account = account;
		
		self.lists = account.lists;
		self.subscriptions = account.listSubscriptions;
	}
	return self;
}

- (void)dealloc {
	HTMLController.delegate = nil;
	[HTMLController invalidateRefreshTimer];
	[HTMLController release];
	
	[lists release];
	[subscriptions release];
	
	[currentSheet release];
	
	[super dealloc];
}


- (void)windowDidLoad {
	HTMLController.webView = self.webView;
	[HTMLController selectHomeTimeline];
	[HTMLController loadWebView];

	// Set window title to account name
	NSString *screenName = HTMLController.account.screenName;
	if (screenName) 
		[[self window] setTitle:screenName];

	[self reloadUsersMenu];
	[self reloadListsMenu];
	
	// Start loading lists
	[self loadListsOfUser:nil];
	
	// Automatically reload the current timeline over the network if this is the first time the web view is loaded.
	HTMLController.suppressNetworkErrorAlerts = YES;
	[HTMLController loadTimeline:HTMLController.timeline];
	
}	

- (BOOL)windowShouldClose {
	return YES;
}

#pragma mark Users
#define kUsersMenuPresetItems 7

- (void)reloadUsersMenu {
	// Remove all items after separator and insert screen names of all accounts.
	while (usersPopUp.menu.numberOfItems > kUsersMenuPresetItems) {
		[usersPopUp.menu removeItemAtIndex:kUsersMenuPresetItems];
	}
	
	// Insert
	for (TwitterAccount *account  in HTMLController.twitter.accounts) {
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		item.title = account.screenName;
		item.action = @selector(selectAccount:);
		item.representedObject = account;
		if (account == HTMLController.account) {
			// Put checkmark next to current account
			[item setState:NSOnState];
		}
		
		[usersPopUp.menu addItem:item];
	}
}

- (IBAction)goToUser:(id)sender {
}

- (IBAction)myProfile:(id)sender {
	[self showUserPage:HTMLController.account.screenName];
}

- (IBAction)addAccount:(id)sender {
	AddAccount* sheet = [[[AddAccount alloc] initWithTwitter:HTMLController.twitter] autorelease];
	sheet.delegate = self;
	[sheet askInWindow: [self window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)];
	self.currentSheet = sheet;
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	self.currentSheet = nil;
}

- (IBAction)editAccounts:(id)sender {
}

- (void)didLoginToAccount:(TwitterAccount*)anAccount {
	HTMLController.account = anAccount;
	
	// Set window title to account name
	[[self window] setTitle:anAccount.screenName];
	
	if (HTMLController.webViewHasValidHTML) {
		//[self.webView setDocumentElement:@"current_account" innerHTML:[HTMLController currentAccountHTML]];
		[self.webView scrollToTop];
	}
	[HTMLController selectHomeTimeline];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: anAccount.screenName forKey: @"currentAccount"];
	
	[self reloadUsersMenu];
	[self reloadListsMenu];
	[self loadListsOfUser:nil];
}

- (IBAction)selectAccount:(id)sender {
	TwitterAccount *account = [sender representedObject];
	if (account) 
		[self didLoginToAccount:account];
}

/*
- (void)reloadUsersMenu {
	TwitterAccount *account = HTMLController.account;
	if (account == nil) return;
	
	// Remove all items.
	while (usersPopUp.menu.numberOfItems > kUsersMenuPresetItems) {
		[usersPopUp.menu removeItemAtIndex:kUsersMenuPresetItems];
	}

	// Sort users by screen name
	NSMutableArray *allUsers = [NSMutableArray arrayWithArray:[twitter.users allObjects]];
	NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"screenName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	[allUsers sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
	
	// Insert users
	for (TwitterUser *user in allUsers) {
		[usersPopUp.menu addItemWithTitle:user.screenName action:@selector(selectUser:) keyEquivalent:@""];
	}
}

- (IBAction)selectUser:(id)sender {
}
*/

#pragma mark Lists
#define kListsMenuPresetItems 1

- (void)reloadListsMenu {
	NSMenuItem *menuItem;

	// Remove all items.
	while (listsPopUp.menu.numberOfItems > kListsMenuPresetItems) {
		[listsPopUp.menu removeItemAtIndex:kListsMenuPresetItems];
	}
	
	// Insert lists
	for (TwitterList *list in lists) {
		menuItem = [[[NSMenuItem alloc] init] autorelease];
		menuItem.title = [list.fullName substringFromIndex:1];
		menuItem.action = @selector(selectList:);
		menuItem.representedObject = list;
		[listsPopUp.menu addItem:menuItem];
	}
	
	// Separator
	if (lists.count > 0 && subscriptions.count > 0) {
		[listsPopUp.menu addItem:[NSMenuItem separatorItem]];
	}
	
	// Insert subscriptions
	for (TwitterList *list in subscriptions) {
		menuItem = [[[NSMenuItem alloc] init] autorelease];
		menuItem.title = [list.fullName substringFromIndex:1];
		menuItem.action = @selector(selectList:);
		menuItem.representedObject = list;
		[listsPopUp.menu addItem:menuItem];
	}
	
	// Empty menu
	if (lists.count == 0 && subscriptions.count == 0) {
		[listsPopUp.menu addItemWithTitle:@"No lists" action:@selector(disabledMenuItem:) keyEquivalent:@""];
	}
	
}

- (IBAction)selectList:(id)sender {
	TwitterList *aList = [sender representedObject];
	[HTMLController loadList:aList];
}

- (void)loadListsOfUser:(NSString*)userOrNil {
	// Load user's own lists.
	TwitterLoadListsAction *listsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:NO] autorelease];
	listsAction.completionTarget= self;
	listsAction.completionAction = @selector(didLoadLists:);
	[HTMLController startTwitterAction:listsAction];
	
	// Load lists that user subscribes to.
	TwitterLoadListsAction *subscriptionsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:YES] autorelease];
	subscriptionsAction.completionTarget= self;
	subscriptionsAction.completionAction = @selector(didLoadListSubscriptions:);
	[HTMLController startTwitterAction:subscriptionsAction];
}

- (void)didLoadLists:(TwitterLoadListsAction *)action {
	// Keep the old list objects that match new ones because it caches the status updates
	[HTMLController.account synchronizeExisting:lists withNew:action.lists];
	[self reloadListsMenu];
}

- (void)didLoadListSubscriptions:(TwitterLoadListsAction *)action {
	[HTMLController.account synchronizeExisting: subscriptions withNew:action.lists];
	[self reloadListsMenu];
}


#pragma mark Actions

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
	HTMLController.customPageTitle = nil;
	[HTMLController selectHomeTimeline];
}

- (IBAction)mentions:(id)sender {
	HTMLController.customPageTitle = [NSString stringWithFormat:@"@%@ <b>Mentions</b>", HTMLController.account.screenName];
	[HTMLController selectMentionsTimeline];
}

- (IBAction)directMessages:(id)sender {
	HTMLController.customPageTitle = @"<b>Direct</b> Messages";
	[HTMLController selectDirectMessageTimeline];
}

- (IBAction)favorites:(id)sender {
	HTMLController.customPageTitle = @"Your <b>Favorites</b>";
	[HTMLController selectFavoritesTimeline];
}

- (IBAction)refresh:(id)sender {
	[HTMLController loadTimeline:HTMLController.timeline];
}

- (IBAction)disabledMenuItem:(id)sender {
	// Do nothing
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	return (menuItem.action != @selector(disabledMenuItem:));
}

#pragma mark Web actions

- (void)retweet:(NSNumber*)identifier {
	TwitterMessage *message = [HTMLController.twitter statusWithIdentifier: identifier];
	if (message == nil) return;
}

- (void) replyToMessage: (NSNumber*)identifier {
	TwitterMessage *message = [HTMLController.twitter statusWithIdentifier: identifier];
	if (message == nil) return;
}

- (void) directMessageWithTweet:(NSNumber*)identifier {
	TwitterMessage *message = [HTMLController.twitter statusWithIdentifier: identifier];
	if (message == nil) return;
}

- (void) showUserPage:(NSString*)screenName {
	// Use a custom timeline showing the user's tweets, but with a big header showing the user's info.
	TwitterUser *user = [HTMLController.twitter userWithScreenName:screenName];
	if (user == nil) {
		// Create an empty user and add it to the Twitter set
		user = [[[TwitterUser alloc] init] autorelease];
		user.screenName = screenName;
		user.identifier = [NSNumber numberWithInt: -1]; // -1 signifies that user info has not been loaded
	}
	
	// Create and show the user window
	UserWindowController *controller = [[[UserWindowController alloc] initWithTwitter:HTMLController.twitter account:HTMLController.account user:user] autorelease];
	[controller showWindow:nil];
	[appDelegate.windowControllers addObject:controller];
}

- (void) searchForQuery:(NSString*)query {
}	

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
}

#pragma mark WebView policy delegate

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id)listener {
	
	NSString *scheme = [[request URL] scheme];
	
	// Handle Actions ourselves
	if ([scheme isEqualToString:@"action"]) {
		NSString *actionName = [[request URL] resourceSpecifier];
		NSNumber *messageIdentifier = [HTMLController number64WithString:[actionName lastPathComponent]];
		
		if ([actionName hasPrefix:@"login"]) { // Log in
			[self addAccount:nil];
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
		} else {
			// handleWebAction: returns a BOOL to indicate whether or not it handled the action, but it's not needed here.
			[HTMLController handleWebAction:actionName];
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
	HTMLController.webViewHasValidHTML = YES;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	//[appDelegate decrementNetworkActionCount];
	HTMLController.webViewHasValidHTML = YES;
}

#pragma mark TimelineHTMLController delegate

- (void)didSelectTimeline:(TwitterTimeline *)timeline {
	int index = -1;
	if (timeline == HTMLController.account.homeTimeline) {
		index = 0;
	} else if (timeline == HTMLController.account.mentions) {
		index = 1;
	} else if (timeline == HTMLController.account.directMessages) {
		index = 2;
	} else if (timeline == HTMLController.account.favorites) {
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
}

@end
