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
#import "HelTweeticaAppDelegate.h"

#import "Twitter.h"
#import "TwitterAccount.h"

#import "TwitterLoadListsAction.h"


#define LKToolbarAccounts @"Accounts"
#define LKToolbarFriends @"Friends"
#define LKToolbarSearch @"Search"
#define LKToolbarLists @"Lists"
#define LKToolbarReload @"Reload"
#define LKToolbarAnalyze @"Analyze"
#define LKToolbarCompose @"Compose"



@implementation MainWindowController
@synthesize webView, accountsPopUp, timelineSegmentedControl, usersPopUp, listsPopUp, searchField;
@synthesize twitter, timelineHTMLController, currentSheet;


- (id)initWithTwitter:(Twitter*)aTwitter {
	self = [super initWithWindowNibName:@"MainWindow"];
	if (self) {
		self.twitter = aTwitter;
		
		appDelegate = [NSApp delegate];
		
		// Timeline HTML Controller generates the HTML from a timeline
		self.timelineHTMLController = [[[TimelineHTMLController alloc] init] autorelease];
		timelineHTMLController.twitter = aTwitter;
		timelineHTMLController.delegate = self;
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	[timelineHTMLController release];
	
	[currentSheet release];
	
	[super dealloc];
}


- (void)windowDidLoad {
	timelineHTMLController.webView = self.webView;
	[timelineHTMLController selectHomeTimeline];
	[timelineHTMLController loadWebView];

	// Set window title to account name
	NSString *screenName = timelineHTMLController.account.screenName;
	if (screenName) 
		[[self window] setTitle:screenName];

	[self reloadAccountsMenu];
	[self reloadUsersMenu];
	[self reloadListsMenu];
	
	// Start loading lists
	[self loadListsOfUser:nil];
}	

- (BOOL)windowShouldClose {
	return YES;
}

#pragma mark Accounts
#define kAccountsMenuPresetItems 4

- (void)reloadAccountsMenu {
	// Remove all items after separator and insert screen names of all accounts.
	NSMenu *accountsMenu = accountsPopUp.menu;
	while (accountsMenu.numberOfItems > kAccountsMenuPresetItems) {
		[accountsMenu removeItemAtIndex:kAccountsMenuPresetItems];
	}
	
	// Insert
	for (TwitterAccount *account  in twitter.accounts) {
		[accountsMenu addItemWithTitle:account.screenName action:@selector(selectAccount:) keyEquivalent:@""];
		if (account == timelineHTMLController.account) {
			// Put checkmark next to current account
			NSMenuItem *item = [accountsPopUp lastItem];
			[item setState:NSOnState];
		}
	}
}

- (IBAction)addAccount:(id)sender {
	AddAccount* sheet = [[[AddAccount alloc] initWithTwitter:twitter] autorelease];
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
	timelineHTMLController.account = anAccount;
	
	// Set window title to account name
	[[self window] setTitle:anAccount.screenName];
	
	if (timelineHTMLController.webViewHasValidHTML) {
		//[self.webView setDocumentElement:@"current_account" innerHTML:[timelineHTMLController currentAccountHTML]];
		[self.webView scrollToTop];
	}
	[timelineHTMLController selectHomeTimeline];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: anAccount.screenName forKey: @"currentAccount"];
	
	[self reloadAccountsMenu];
	[self reloadUsersMenu];
	[self reloadListsMenu];
	[self loadListsOfUser:nil];
}

- (IBAction)selectAccount:(id)sender {
	NSString *screenName = [sender title];
	TwitterAccount *account = [twitter accountWithScreenName:screenName];
	
	if (account) 
		[self didLoginToAccount:account];
}

#pragma mark Users
#define kUsersMenuPresetItems 3

- (void)reloadUsersMenu {
	TwitterAccount *account = timelineHTMLController.account;
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

#pragma mark Lists
#define kListsMenuPresetItems 1

- (void)reloadListsMenu {
	NSMenuItem *menuItem;
	TwitterAccount *account = timelineHTMLController.account;
	if (account == nil) return;

	// Remove all items.
	while (listsPopUp.menu.numberOfItems > kListsMenuPresetItems) {
		[listsPopUp.menu removeItemAtIndex:kListsMenuPresetItems];
	}
	
	// Insert lists
	for (TwitterList *list in account.lists) {
		menuItem = [[[NSMenuItem alloc] init] autorelease];
		menuItem.title = [list.fullName substringFromIndex:1];
		menuItem.action = @selector(selectList:);
		menuItem.representedObject = list;
		[listsPopUp.menu addItem:menuItem];
	}
	
	// Separator
	if (account.lists.count > 0 && account.listSubscriptions.count > 0) {
		[listsPopUp.menu addItem:[NSMenuItem separatorItem]];
	}
	
	// Insert subscriptions
	for (TwitterList *list in account.listSubscriptions) {
		menuItem = [[[NSMenuItem alloc] init] autorelease];
		menuItem.title = [list.fullName substringFromIndex:1];
		menuItem.action = @selector(selectList:);
		menuItem.representedObject = list;
		[listsPopUp.menu addItem:menuItem];
	}
	
	// Empty menu
	if (account.lists.count == 0 && account.listSubscriptions.count == 0) {
		[listsPopUp.menu addItemWithTitle:@"No lists" action:@selector(disabledMenuItem:) keyEquivalent:@""];
	}
	
}

- (IBAction)selectList:(id)sender {
	TwitterList *list = [sender representedObject];
	[timelineHTMLController loadList:list];
}

- (void)loadListsOfUser:(NSString*)userOrNil {
	// Load user's own lists.
	TwitterLoadListsAction *listsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:NO] autorelease];
	listsAction.completionTarget= self;
	listsAction.completionAction = @selector(didLoadLists:);
	[timelineHTMLController startTwitterAction:listsAction];
	
	// Load lists that user subscribes to.
	TwitterLoadListsAction *subscriptionsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:YES] autorelease];
	subscriptionsAction.completionTarget= self;
	subscriptionsAction.completionAction = @selector(didLoadListSubscriptions:);
	[timelineHTMLController startTwitterAction:subscriptionsAction];
}

- (void)didLoadLists:(TwitterLoadListsAction *)action {
	// Keep the old list objects that match new ones because it caches the status updates
	[timelineHTMLController.account synchronizeExisting:timelineHTMLController.account.lists withNew:action.lists];
	[self reloadListsMenu];
}

- (void)didLoadListSubscriptions:(TwitterLoadListsAction *)action {
	[timelineHTMLController.account synchronizeExisting: timelineHTMLController.account.listSubscriptions withNew:action.lists];
	[self reloadListsMenu];
}


#pragma mark Actions

- (IBAction)selectTimelineWithSegmentedControl:(id)sender {
	int index = [sender selectedSegment];
	switch (index) {
		case 0:
			[timelineHTMLController selectHomeTimeline];
			break;
		case 1:
			[timelineHTMLController selectMentionsTimeline];
			break;
		case 2:
			[timelineHTMLController selectDirectMessageTimeline];
			break;
		case 3:
			[timelineHTMLController selectFavoritesTimeline];
			break;
		default:
			break;
	}
}

- (IBAction)homeTimeline:(id)sender {
	[timelineHTMLController selectHomeTimeline];
}

- (IBAction)mentions:(id)sender {
	[timelineHTMLController selectMentionsTimeline];
}

- (IBAction)directMessages:(id)sender {
	[timelineHTMLController selectDirectMessageTimeline];
}

- (IBAction)favorites:(id)sender {
	[timelineHTMLController selectFavoritesTimeline];
}

- (IBAction)refresh:(id)sender {
	[timelineHTMLController loadTimeline:timelineHTMLController.timeline];
}

- (IBAction)myProfile:(id)sender {
	//[timelineHTMLController loadTimeline:timelineHTMLController.timeline];
}

- (IBAction)disabledMenuItem:(id)sender {
	// Do nothing
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	return (menuItem.action != @selector(disabledMenuItem:));
}

#pragma mark Web actions

- (void)retweet:(NSNumber*)identifier {
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	if (message == nil) return;
}

- (void) replyToMessage: (NSNumber*)identifier {
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	if (message == nil) return;
}

- (void) directMessageWithTweet:(NSNumber*)identifier {
	TwitterMessage *message = [twitter statusWithIdentifier: identifier];
	if (message == nil) return;
}

- (void) showUserPage:(NSString*)screenName {
}

- (void) searchForQuery:(NSString*)query {
}	

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
}

#pragma mark TimelineHTMLController delegate

- (void)didSelectTimeline:(TwitterTimeline *)timeline {
	int index = -1;
	if (timeline == timelineHTMLController.account.homeTimeline) {
		index = 0;
	} else if (timeline == timelineHTMLController.account.mentions) {
		index = 1;
	} else if (timeline == timelineHTMLController.account.directMessages) {
		index = 2;
	} else if (timeline == timelineHTMLController.account.favorites) {
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

#pragma mark WebView policy delegate

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id)listener {
	
	NSString *scheme = [[request URL] scheme];
	
	// Handle Actions ourselves
	if ([scheme isEqualToString:@"action"]) {
		NSString *actionName = [[request URL] resourceSpecifier];
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
			// handleWebAction: returns a BOOL to indicate whether or not it handled the action, but it's not needed here.
			[timelineHTMLController handleWebAction:actionName];
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
	[appDelegate incrementNetworkActionCount];
	timelineHTMLController.webViewHasValidHTML = YES;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	[appDelegate decrementNetworkActionCount];
	timelineHTMLController.webViewHasValidHTML = YES;
	
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

@end
