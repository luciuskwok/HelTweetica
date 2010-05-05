    //
//  SearchResultsViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "SearchResultsViewController.h"
#import "TwitterSearchAction.h"


@implementation SearchResultsViewController

// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithQuery:(NSString*)query {
	self = [super initWithNibName:@"SearchResults" bundle:nil];
	if (self) {
		self.currentTimeline = [NSMutableArray array]; // Always start with an empty array of messages for Search.
		self.customPageTitle = [NSString stringWithFormat: @"Search for &ldquo;<b>%@</b>&rdquo;", [self htmlSafeString:query]];
		self.customTabName = NSLocalizedString (@"Results", @"tab");
		
		// Create Twitter action to load search results into the current timeline.
		TwitterSearchAction *action = [[[TwitterSearchAction alloc] initWithQuery:query count:defaultLoadCount] autorelease];
		self.currentTimelineAction = action;
		[self reloadCurrentTimeline];
	}
	return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
 	// Start search
	[self reloadCurrentTimeline];
	
	[super viewDidLoad];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
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
	
	// Limit the length of the timeline
	if (action.timeline.count > kMaxNumberOfMessagesInATimeline) {
		NSRange removalRange = NSMakeRange(kMaxNumberOfMessagesInATimeline, action.timeline.count - kMaxNumberOfMessagesInATimeline);
		[action.timeline removeObjectsInRange:removalRange];
	}
	
	// Finished loading, so update tweet area and remove loading spinner.
	[self rewriteTweetArea];	
}

@end
