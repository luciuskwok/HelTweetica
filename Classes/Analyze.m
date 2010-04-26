//
//  Analyze.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/2/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "Analyze.h"
#import "TwitterMessage.h"


@interface Analyze (PrivateMethods)
- (NSMutableArray*) analyzeTimeline: (NSArray*) aTimeline;
- (NSMutableDictionary*) itemWithUsername: (NSString*) aUsername inArray: (NSArray*) anArray;
- (NSString*) renderedHTMLWithAnalysis:(NSArray*)analysis;
@end

@implementation Analyze
@synthesize webView, timeline, popover;

- (id)init {
	if (self = [super initWithNibName:@"Analyze" bundle:nil]) {
		// Content size for popover
		if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
			[self setContentSizeForViewInPopover: CGSizeMake(320, 460)];
		}
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	NSMutableArray *analysis = [self analyzeTimeline: self.timeline];
	
	// Sort analysis by count
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"count" ascending:NO];
	[analysis sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
	[descriptor release];
	
	NSString *html = [self renderedHTMLWithAnalysis:analysis];
	NSURL *baseURL = [NSURL fileURLWithPath: [[NSBundle mainBundle] bundlePath]];
	[self.webView loadHTMLString:html baseURL:baseURL];
}

- (NSMutableArray*) analyzeTimeline: (NSArray*) aTimeline {
	NSMutableArray *analysis = [NSMutableArray array];
	
	TwitterMessage *message;
	NSString *user;
	BOOL favorite;
	NSMutableDictionary *entry;
	int messageCount, favoriteCount;
	
	for (message in aTimeline) {
		user = [message screenName];
		favorite = [message isFavorite];
		
		// Create an entry if it doesn't exist for this user
		entry = [self itemWithUsername: user inArray: analysis];
		if (entry == nil) {
			entry = [NSMutableDictionary dictionary];
			[analysis addObject: entry];
			[entry setObject:user forKey:@"username"];
		}
		
		// Increment message and favorite counts
		messageCount = [[entry objectForKey:@"count"] intValue] + 1;
		favoriteCount = [[entry objectForKey:@"favorites"] intValue] + (favorite ? 1 : 0);
		
		// Save changes
		[entry setObject:[NSNumber numberWithInt:messageCount] forKey:@"count"];
		[entry setObject:[NSNumber numberWithInt:favoriteCount] forKey:@"favorites"];
	}
	
	return analysis;
}

- (NSMutableDictionary*) itemWithUsername: (NSString*) aUsername inArray: (NSArray*) anArray {
	NSMutableDictionary *item;
	for (item in anArray) {
		if ([aUsername isEqualToString: [item objectForKey:@"username"]])
			return item;
	}
	return nil;
}

- (NSString*) renderedHTMLWithAnalysis:(NSArray*)analysis {
	// HTML header
	NSMutableString *html = [[[NSMutableString alloc] init] autorelease];
	[html appendString:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"];
	[html appendString:@"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">\n"];
	[html appendString:@"<head>\n"];
	[html appendString:@"<meta name='viewport' content='width=320' />"];
	[html appendString:@"<style>body{font:17px/20px Helvetica;color:#333;}b{color:#000;}</style>"];

	// Body
	[html appendString:@"</head><body>"];
	[html appendFormat:@"<div class='tweet_area'><b>Most frequent tweeters</b><br> out of %d tweets:<br><br>", [timeline count]];
	
	if ((timeline == nil) || ([timeline count] == 0)) {
		[html appendString:@"No tweets to analyze!"];
	} else {
		NSDictionary *entry;
		NSString *user;
		int count, favorites;
		
		for (entry in analysis) {
			user = [entry objectForKey:@"username"];
			count = [[entry objectForKey:@"count"] intValue];
			favorites = [[entry objectForKey:@"favorites"] intValue];
			
			[html appendFormat:@"<b>%@</b> ", user];
			if (count == 1) {
				[html appendString:@"1 tweet"];
			} else {
				[html appendFormat:@"%d tweets", count];
			}
			if (favorites == 0) {
				[html appendString:@"."];
			} else if (favorites == 1) {
				[html appendString:@", 1 star."];
			} else {
				[html appendFormat:@", %d stars.", favorites];
			}
			[html appendString:@"<br>"];
		}
	}

	// Close artboard div, body. and html tags
	[html appendString:@"</div></body></html>\n"];
	
	return html;
}

- (IBAction) close: (id) sender {
	if (popover != nil) {
		[popover dismissPopoverAnimated:YES];
		// Make sure delegate knows popover has been removed
		[popover.delegate popoverControllerDidDismissPopover:popover];
	} else {
		[self dismissModalViewControllerAnimated:YES];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.webView = nil;
}

- (void)dealloc {
	[webView release];
	[timeline release];
    [super dealloc];
}


@end
