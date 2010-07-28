//
//  SearchResultsHTMLController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
		timeline.database = twitter.database;
		timeline.databaseTableName = [NSString stringWithFormat:@"SearchResults_%@", aQuery];
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
	//[result replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (NSString*) webPageTemplate {
	return [self loadHTMLTemplate:@"basic-template"];
}

#pragma mark TwitterTimelineDelegate

- (void) timeline:(TwitterTimeline *)aTimeline didLoadWithAction:(TwitterLoadTimelineAction *)action {
	// Twitter cache.
	[twitter addStatusUpdates:action.loadedMessages];
	[twitter addStatusUpdates:action.retweetedMessages];
	[twitter addUsers:action.users]; // Don't replace existing User info in the database.
	
	// Timeline
	[aTimeline addMessages:action.loadedMessages updateGap:YES];
	
	isLoading = NO;
	
	if (timeline == aTimeline) {
		self.messages = [timeline statusUpdatesWithLimit: maxTweetsShown];
		[self rewriteTweetArea];	
	}
}



@end
