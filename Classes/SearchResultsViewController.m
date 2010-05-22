    //
//  SearchResultsViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/5/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SearchResultsViewController.h"
#import "TwitterTimeline.h"
#import "TwitterSearchAction.h"
#import "TwitterSavedSearchAction.h"


@implementation SearchResultsViewController
@synthesize saveButton, query;


// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithQuery:(NSString*)aQuery {
	self = [super initWithNibName:@"SearchResults" bundle:nil];
	if (self) {
		self.query = aQuery;
		self.customPageTitle = [NSString stringWithFormat: @"Search for &ldquo;<b>%@</b>&rdquo;", [self htmlSafeString:query]];
		self.customTabName = NSLocalizedString (@"Results", @"tab");
		self.defaultLoadCount = @"50"; // Limit number of tweets to request.
		maxTweetsShown = 1000; // Allow for a larger limit for searches.
		
		// Timeline
		self.currentTimeline = [[[TwitterTimeline alloc] init] autorelease]; // Always start with an empty array of messages for Search.
		currentTimeline.loadAction = [[[TwitterSearchAction alloc] initWithQuery:query count:defaultLoadCount] autorelease];
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

#pragma mark TwitterTimelineDelegate

- (void) timeline:(TwitterTimeline *)timeline didLoadWithAction:(TwitterLoadTimelineAction *)action {
	// Synchronize timeline with Twitter cache.
	[twitter synchronizeStatusesWithArray:action.timeline.messages updateFavorites:NO];
	[twitter addUsers:action.users];
	[twitter save];
	
	if (timeline == currentTimeline) {
		[self rewriteTweetArea];	
	}
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
