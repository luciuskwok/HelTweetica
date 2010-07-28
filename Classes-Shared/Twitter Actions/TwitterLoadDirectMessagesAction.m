//
//  TwitterLoadDirectMessagesAction.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/27/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterLoadDirectMessagesAction.h"
#import "TwitterDirectMessageJSONParser.h"


@implementation TwitterLoadDirectMessagesAction
@synthesize loadedMessages, users;

- (id)initWithTwitterMethod:(NSString*)method {
	self = [super init];
	if (self) {
		self.twitterMethod = method;
	}
	return self;
}
- (void) dealloc {
	[loadedMessages release];
	[users release];
	[super dealloc];
}

- (void) start {
	[self startGetRequest];
}

- (void) parseReceivedData:(NSData*)data {
	if (statusCode < 400) {
		TwitterDirectMessageJSONParser *parser = [[[TwitterDirectMessageJSONParser alloc] init] autorelease];
		parser.receivedTimestamp = [NSDate date];
		[parser parseJSONData:receivedData];
		self.users = parser.users;
		self.loadedMessages = parser.messages;
	}
}

@end
