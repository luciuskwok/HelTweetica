    //
//  SearchResultsViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "SearchResultsViewController.h"
#import "TwitterSearchAction.h"
#import "TwitterSavedSearchAction.h"


@implementation SearchResultsViewController
@synthesize saveButton, query;


// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithQuery:(NSString*)aQuery {
	self = [super initWithNibName:@"SearchResults" bundle:nil];
	if (self) {
		self.query = aQuery;
		self.currentTimeline = [NSMutableArray array]; // Always start with an empty array of messages for Search.
		self.customPageTitle = [NSString stringWithFormat: @"Search for &ldquo;<b>%@</b>&rdquo;", [self htmlSafeString:query]];
		self.customTabName = NSLocalizedString (@"Results", @"tab");
		self.defaultLoadCount = @"50"; // Limit number of tweets to request.
		maxTweetsShown = 1000; // Allow for a larger limit for searches.
		
		// Create Twitter action to load search results into the current timeline.
		TwitterSearchAction *action = [[[TwitterSearchAction alloc] initWithQuery:query count:defaultLoadCount] autorelease];
		self.currentTimelineAction = action;
		[self reloadCurrentTimeline];
	}
	return self;
}

- (void)dealloc {
	[saveButton release];
	[query release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
 	// Start search
	[self reloadCurrentTimeline];
	
	// If this is a saved search, disable the save button
	// Filter set by search term
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"query LIKE[cd] %@", query];
	NSArray *filteredResults = [currentAccount.savedSearches filteredArrayUsingPredicate:predicate];
	if (filteredResults.count != 0) {
		saveButton.title = NSLocalizedString (@"Saved", @"button");
		saveButton.enabled = NO;
	}
	
	[super viewDidLoad];
}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.saveButton = nil;
}

#pragma mark HTML formatting

- (NSString *)htmlSafeString:(NSString *)string {
	NSMutableString *result = [NSMutableString stringWithString:string];
	[result replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (NSString*) webPageTemplate {
	// Load main template
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSString *templateFile = [mainBundle stringByAppendingPathComponent:@"basic-template.html"];
	NSError *error = nil;
	NSMutableString *html  = [NSMutableString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&error];
	if (error) { NSLog (@"Error loading conversation-template.html: %@", [error localizedDescription]); }
	
	// Add any customization here.
	
	return html;
}

#pragma mark TwitterAction

- (void)didReloadCurrentTimeline:(TwitterLoadTimelineAction *)action {
	// Synchronize timeline with Twitter cache. Ignore favorites flag in Search results because they're always false.
	[twitter synchronizeStatusesWithArray:action.timeline updateFavorites:NO];
	[twitter addUsers:action.users];
	
	// Finished loading, so update tweet area and remove loading spinner.
	[self rewriteTweetArea];	
}

#pragma mark IBAction

- (IBAction)saveSearch:(id)sender {
	// Update button 
	saveButton.title = NSLocalizedString (@"Saving...", @"button");
	saveButton.enabled = NO;
	
	// Send action to save search query
	TwitterSavedSearchAction *action = [[[TwitterSavedSearchAction alloc] initWithCreateQuery:query] autorelease];
	action.completionTarget = self;
	action.completionAction = @selector(didSaveSearch:);
	[self startTwitterAction: action];
}

- (void)didSaveSearch:(TwitterSavedSearchAction *)action {
	// Update button 
	if (action.statusCode < 400 || action.statusCode == 403) {
		// Success
		saveButton.title = NSLocalizedString (@"Saved", @"button");
		saveButton.enabled = NO;
		// Clear cache of saved searches. Or add the search that was just saved.
		[currentAccount.savedSearches removeAllObjects];
	} else {
		// Failure: allow user to re-save search.
		saveButton.title = NSLocalizedString (@"Save Search", @"button");
		saveButton.enabled = YES;
	}
}

@end
