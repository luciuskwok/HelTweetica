//
//  SearchWindowController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/24/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SearchWindowController.h"
#import "SearchResultsHTMLController.h"

#import "TwitterSavedSearchAction.h"
#import "TwitterLoadTimelineAction.h"

#import "HelTweeticaAppDelegate.h"



@implementation SearchWindowController
@synthesize saveButton, query;

- (id)initWithQuery:(NSString*)aQuery {
	self = [super initWithWindowNibName:@"SearchWindow"];
	if (self) {
		appDelegate = [NSApp delegate];
		self.query = aQuery;
		
		SearchResultsHTMLController *controller = [[[SearchResultsHTMLController alloc] initWithQuery:aQuery twitter:appDelegate.twitter] autorelease];
		controller.twitter = appDelegate.twitter;
		controller.delegate = self;
		self.htmlController = controller;
	
		// Listen for changes to Saved Searches list
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(savedSearchesDidChange:) name:@"savedSearchesDidChange" object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[query release];
	[super dealloc];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	NSString *account = [aDecoder decodeObjectForKey:@"accountScreenName"];
	NSString *aQuery = [aDecoder decodeObjectForKey:@"query"];
	
	self = [self initWithQuery:aQuery];
	if (self) {
		[self setAccountWithScreenName: account];
		[self.window setFrameAutosaveName: [aDecoder decodeObjectForKey:@"windowFrameAutosaveName"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:htmlController.account.screenName forKey:@"accountScreenName"];
	[aCoder encodeObject:query forKey:@"query"];
	[aCoder encodeObject:[self.window frameAutosaveName ] forKey:@"windowFrameAutosaveName"];
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
	} else {
		saveButton.title = NSLocalizedString (@"Save Search", @"button");
		[saveButton setEnabled: YES];
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
	if ([aQuery isEqualToString: [searchField stringValue]] == NO) {
		[searchField setStringValue:aQuery];
	}
	
	// Copy credentials from old query to new one.
	SearchResultsHTMLController *controller = [[[SearchResultsHTMLController alloc] initWithQuery:aQuery twitter:appDelegate.twitter] autorelease];
	controller.twitter = htmlController.twitter;
	controller.account = htmlController.account;
	controller.delegate = self;
	
	// Disconnect old controller
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
	[htmlController.twitter startTwitterAction:action withAccount:nil];
}

- (void)didSaveSearch:(TwitterSavedSearchAction *)action {
	// Update button 
	if (action.statusCode < 400 || action.statusCode == 403) {
		// Success
		saveButton.title = NSLocalizedString (@"Saved", @"button");
		[saveButton setEnabled: NO];
		[self loadSavedSearches];
	} else {
		// Failure: allow user to re-save search.
		saveButton.title = NSLocalizedString (@"Save Search", @"button");
		[saveButton setEnabled: YES];
	}
}

@end
