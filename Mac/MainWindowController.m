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
#import "Twitter.h"
#import "TwitterAccount.h"


#define LKToolbarAccounts @"Accounts"
#define LKToolbarFriends @"Friends"
#define LKToolbarSearch @"Search"
#define LKToolbarLists @"Lists"
#define LKToolbarReload @"Reload"
#define LKToolbarAnalyze @"Analyze"
#define LKToolbarCompose @"Compose"



@implementation MainWindowController
@synthesize webView, accountsPopUp, twitter, currentAccount, currentSheet;

- (id)initWithTwitter:(Twitter*)aTwitter {
	self = [super initWithWindowNibName:@"MainWindow"];
	if (self) {
		self.twitter = aTwitter;
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	[currentSheet release];
	[super dealloc];
}


- (void)windowDidLoad {
	[self initToolbar];

	// Create HTML to display
	NSMutableString *html = [NSMutableString string];
	[html appendString:@"<b>Some</b> text."];
	
	[webView loadHTMLString:html];
}	

- (BOOL)windowShouldClose {
	return YES;
}

#pragma mark Accounts

#define kAccountsMenuPresetItems 3

- (void)reloadAccountsMenu {
	// Remove all items after separator and insert screen names of all accounts.
	NSMenu *accountsMenu = accountsPopUp.menu;
	while (accountsMenu.numberOfItems > kAccountsMenuPresetItems) {
		[accountsMenu removeItemAtIndex:kAccountsMenuPresetItems];
	}
	
	// Insert
	for (TwitterAccount *account  in twitter.accounts) {
		[accountsMenu addItemWithTitle:account.screenName action:@selector(selectAccount:) keyEquivalent:@""];
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
	self.currentAccount = anAccount;
	if (webViewHasValidHTML) {
		//[webView setDocumentElement:@"current_account" innerHTML:[self currentAccountHTML]];
		[webView scrollToTop];
	}
	//[self selectHomeTimeline];
	//[self startLoadingCurrentTimeline];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: self.currentAccount.screenName forKey: @"currentAccount"];
}

#pragma mark Toolbar 

- (void)initToolbar {
	//[[accountsPopUp cell] setControlSize: NSSmallControlSize];
	
	// Create toolbar
	NSToolbar	*toolbar = [[NSToolbar alloc] initWithIdentifier:@"Main"];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setDelegate: self];
	[[self window] setToolbar: toolbar];
	[toolbar release];
	// End toolbar
	
}

- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString*)itemIdentifier label:(NSString*)label toolTip:(NSString*)toolTip view:(NSView*)view {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier] autorelease];
	[toolbarItem setLabel:NSLocalizedString (label, @"")];
	[toolbarItem setPaletteLabel:NSLocalizedString (label, @"")];
	[toolbarItem setToolTip:NSLocalizedString (toolTip, @"")];
	
	// Custom view
	NSSize size = [view frame].size;
	[toolbarItem setView: view];
	[toolbarItem setMaxSize: size];
	[toolbarItem setMinSize: size];
	
	return toolbarItem;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *toolbarItem = nil;
	//NSMenuItem *menuItem = nil;
	//NSString *s;
	
    if ([itemIdentifier isEqual:LKToolbarAccounts]) {
		toolbarItem = [self toolbarItemWithIdentifier:itemIdentifier label:@"Accounts" toolTip:@"Your Twitter accounts." view:accountsPopUp];
		//menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Accounts", @"") action:@selector(accounts:) keyEquivalent:@""] autorelease];
		//[menuItem setTarget:self];
		//[toolbarItem setMenuFormRepresentation:menuItem];

	}
	
	return toolbarItem;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects: 
			LKToolbarAccounts,
			LKToolbarFriends,
			LKToolbarSearch,
			LKToolbarLists,
			LKToolbarReload,
			LKToolbarAnalyze,
			LKToolbarCompose,
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects: 
			LKToolbarAccounts,
			NSToolbarSeparatorItemIdentifier,
			LKToolbarFriends,
			LKToolbarSearch,
			LKToolbarLists,
			NSToolbarFlexibleSpaceItemIdentifier,
			LKToolbarReload,
			LKToolbarAnalyze,
			NSToolbarSeparatorItemIdentifier,
			LKToolbarCompose,
			nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects: 
			nil];
}

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	webViewHasValidHTML = YES;
}

@end
