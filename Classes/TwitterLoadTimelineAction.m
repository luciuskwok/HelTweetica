//
//  TwitterLoadTimelineAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TwitterLoadTimelineAction.h"
#import "TwitterMessageJSONParser.h"


@implementation TwitterLoadTimelineAction
@synthesize timeline, loadedMessages, users, newMessageCount, overlap;

- (id)initWithTwitterMethod:(NSString*)method {
	self = [super init];
	if (self) {
		self.twitterMethod = method;
	}
	return self;
}
- (void) dealloc {
	[timeline release];
	[loadedMessages release];
	[users release];
	[super dealloc];
}

- (void) start {
	[self startGetRequest];
}

- (void) parseReceivedData:(NSData*)data {
	if (statusCode < 400) {
		TwitterMessageJSONParser *parser = [[[TwitterMessageJSONParser alloc] init] autorelease];
		parser.receivedTimestamp = [NSDate date];
		parser.directMessage = [twitterMethod hasPrefix:@"direct_messages"];
		[parser parseJSONData:receivedData];
		self.users = parser.users;
		newMessageCount = parser.messages.count;
		[self mergeTimelineWithMessages: parser.messages];
		self.loadedMessages = parser.messages;
	} else {
		newMessageCount = 0;
	}
}

- (void) mergeTimelineWithMessages:(NSMutableArray*)messages {
	if (timeline == nil) {
		self.timeline = messages;
	} else {
		// Merge downloaded messages with existing messages.
		overlap = NO;
		for (TwitterMessage *message in messages) {
			if ([timeline containsObject:message]) {
				overlap = YES; // Need to do something, maybe mark the last message in the array to signify a gap.
			} else {
				[timeline addObject: message];
			}
		}
		
		// Sort by identifier, descending.
		NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
		[timeline sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
	}
}

@end
