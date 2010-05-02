//
//  TwitterSearchAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterSearchAction.h"
#import "TwitterMessage.h"
#import "TwitterSearchJSONParser.h"


@implementation TwitterSearchAction
@synthesize query, messages;


- (id)initWithQuery:(NSString *)aQuery count:(NSNumber*)count {
	self = [super init];
	if (self) {
		self.query = aQuery;
		
		NSMutableDictionary *theParameters = [NSMutableDictionary dictionary];
		[theParameters setObject:aQuery forKey:@"q"];
		if (count) 
			[theParameters setObject:[count stringValue] forKey:@"rpp"]; // Results per page.
		
		self.parameters = theParameters;
	}
	return self;
}

- (void) dealloc {
	[query release];
	[messages release];
	[super dealloc];
}

// Search uses a completely different URL from the other Twitter methods.
- (void) start {
	NSString *base = @"http://search.twitter.com/search.json"; 
	NSURL *url = [TwitterAction URLWithBase:base query:parameters];
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	[request setHTTPMethod:@"GET"];
	[request setValue:@"HelTweetica/1.0" forHTTPHeaderField:@"User-Agent"];
	[self startURLRequest:request];
}

- (void) parseReceivedData:(NSData*)data {
	if (statusCode < 400) {
		TwitterSearchJSONParser *parser = [[TwitterSearchJSONParser alloc] init];
		parser.receivedTimestamp = [NSDate date];
		self.messages = [parser messagesWithJSONData:receivedData];
		[parser release];
	}
}


@end
