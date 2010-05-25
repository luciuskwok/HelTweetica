//
//  SearchWindowController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/24/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "SearchWindowController.h"
#import "SearchResultsHTMLController.h"

#import "TwitterSavedSearchAction.h"
#import "TwitterLoadTimelineAction.h"



@implementation SearchWindowController
@synthesize saveButton, query;

- (id)initWithTwitter:(Twitter*)aTwitter account:(TwitterAccount*)anAccount query:(NSString*)aQuery {
	self = [super initWithWindowNibName:@"SearchWindow"];
	if (self) {
		appDelegate = [NSApp delegate];
		self.query = aQuery;
		
		SearchResultsHTMLController *controller = [[[SearchResultsHTMLController alloc] initWithQuery:aQuery] autorelease];
		controller.twitter = aTwitter;
		controller.account = anAccount;
		controller.delegate = self;
		self.htmlController = controller;
	}
	return self;
}

- (void)dealloc {
	[query release];
    [super dealloc];
}

- (void)setUpWindowForQuery:(NSString*)aQuery {
	// Set window title
	NSString *title = @"Search";
	if (aQuery.length > 0)
		title = [NSString stringWithFormat:@"Search for “%@”", aQuery];
	[[self window] setTitle:title];
	
	// If this is a saved search, disable the save button
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"query LIKE[cd] %@", aQuery];
	NSArray *filteredResults = [htmlController.account.savedSearches filteredArrayUsingPredicate:predicate];
	if (filteredResults.count != 0) {
		saveButton.title = NSLocalizedString (@"Saved", @"button");
		[saveButton setEnabled: NO];
	}

	// Reload web view
	htmlController.webView = self.webView;
	[htmlController loadWebView];
	
	// Load search results
	[htmlController loadTimeline:htmlController.timeline];
}

- (void)windowDidLoad {
	[self setUpWindowForQuery:query];
	[self loadSavedSearches];
}

- (void) searchForQuery:(NSString*)aQuery {
	// Override this method so that searches appear in the same window instead of creating a new one.

	// Put the query in the search box
	if ([query isEqualToString: [searchField stringValue]] == NO) {
		[searchField setStringValue:query];
	}
	
	// Copy credentials from old query to new one.
	SearchResultsHTMLController *controller = [[[SearchResultsHTMLController alloc] initWithQuery:aQuery] autorelease];
	controller.twitter = htmlController.twitter;
	controller.account = htmlController.account;
	controller.delegate = self;
	
	// Disconnect old controller
	[htmlController invalidateRefreshTimer];
	htmlController.webView = nil;
	htmlController.delegate = nil;

	// Update ivars with new query.
	self.query = aQuery;
	self.htmlController = controller;
	
	// Reload window and web view
	[self setUpWindowForQuery:aQuery];
}	


#pragma mark IBAction

- (IBAction)saveSearch:(id)sender {
	// Update button 
	saveButton.title = NSLocalizedString (@"Saving...", @"button");
	[saveButton setEnabled: NO];
	
	// Send action to save search query
	TwitterSavedSearchAction *action = [[[TwitterSavedSearchAction alloc] initWithCreateQuery:query] autorelease];
	action.completionTarget = self;
	action.completionAction = @selector(didSaveSearch:);
	[htmlController startTwitterAction: action];
}

- (void)didSaveSearch:(TwitterSavedSearchAction *)action {
	// Update button 
	if (action.statusCode < 400 || action.statusCode == 403) {
		// Success
		saveButton.title = NSLocalizedString (@"Saved", @"button");
		[saveButton setEnabled: NO];
		// Clear cache of saved searches. Or add the search that was just saved.
		[htmlController.account.savedSearches removeAllObjects];
	} else {
		// Failure: allow user to re-save search.
		saveButton.title = NSLocalizedString (@"Save Search", @"button");
		[saveButton setEnabled: YES];
	}
}

@end
