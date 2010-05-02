//
//  TwitterLoadTimelineAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterLoadTimelineAction.h"
#import "TwitterMessageJSONParser.h"


@implementation TwitterLoadTimelineAction
@synthesize messages;

- (id)initWithTwitterMethod:(NSString*)method {
	self = [super init];
	if (self) {
		self.twitterMethod = method;
	}
	return self;
}
- (void) dealloc {
	[messages release];
	[super dealloc];
}

- (void) start {
	[self startGetRequest];
}

- (void) parseReceivedData:(NSData*)data {
	if (statusCode < 400) {
		TwitterMessageJSONParser *parser = [[TwitterMessageJSONParser alloc] init];
		parser.receivedTimestamp = [NSDate date];
		parser.directMessage = [twitterMethod hasPrefix:@"direct_messages"];
		self.messages = [parser messagesWithJSONData:receivedData];
		[parser release];
	}
}

@end
