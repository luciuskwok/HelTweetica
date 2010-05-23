//
//  SearchResultsHTMLController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "SearchResultsHTMLController.h"
#import "TwitterSearchAction.h"



@implementation SearchResultsHTMLController


// Designated initializer.
- (id)initWithQuery:(NSString*)aQuery {
	self = [super init];
	if (self) {
		self.customPageTitle = [NSString stringWithFormat: @"Search for &ldquo;<b>%@</b>&rdquo;", [self htmlSafeString:aQuery]];
		self.customTabName = NSLocalizedString (@"Results", @"tab");
		maxTweetsShown = 1000; // Allow for a larger limit for searches.
		
		// Timeline
		self.timeline = [[[TwitterTimeline alloc] init] autorelease]; // Always start with an empty array of messages for Search.
		timeline.loadAction = [[[TwitterSearchAction alloc] initWithQuery:aQuery count:defaultLoadCount] autorelease];
		[self loadTimeline:timeline];
	}
	return self;
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
	// Load basic template
	NSError *error = nil;
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"basic-template" ofType:@"html"];
	NSString *html = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
	if (error != nil)
		NSLog (@"Error loading basic-template.html: %@", [error localizedDescription]);
	return html;
}

#pragma mark TwitterTimelineDelegate

- (void) timeline:(TwitterTimeline *)aTimeline didLoadWithAction:(TwitterLoadTimelineAction *)action {
	// Synchronize timeline with Twitter cache.
	[twitter synchronizeStatusesWithArray:action.timeline.messages updateFavorites:NO];
	[twitter addUsers:action.users];
	[twitter save];
	isLoading = NO;
	
	if (timeline == aTimeline) {
		[self rewriteTweetArea];	
	}
}



@end
