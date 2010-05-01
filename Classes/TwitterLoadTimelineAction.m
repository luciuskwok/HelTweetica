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
@synthesize messages, timelineName;


- (id)initWithTwitterMethod:(NSString*)method sinceIdentifier:(NSNumber*)sinceId maxIdentifier:(NSNumber*)maxId perPage:(NSNumber*)count page:(NSNumber*)page {
	self = [super init];
	if (self) {
		// Create parameters
		NSMutableDictionary *theParameters = [NSMutableDictionary dictionary];
		if (sinceId) [theParameters setObject:[sinceId stringValue] forKey:@"since_id"];
		if (maxId) [theParameters setObject:[maxId stringValue] forKey:@"max_id"];
		if (count) [theParameters setObject:[count stringValue] forKey:@"per_page"];
		if (page) [theParameters setObject:[page stringValue] forKey:@"page"];
		
		self.twitterMethod = method;
		self.parameters = theParameters;
	}
	return self;
}

- (id)initWithTwitterMethod:(NSString*)method sinceIdentifier:(NSNumber*)sinceId maxIdentifier:(NSNumber*)maxId count:(NSNumber*)count page:(NSNumber*)page {
	self = [super init];
	if (self) {
		// Create parameters
		NSMutableDictionary *theParameters = [NSMutableDictionary dictionary];
		if (sinceId) [theParameters setObject:[sinceId stringValue] forKey:@"since_id"];
		if (maxId) [theParameters setObject:[maxId stringValue] forKey:@"max_id"];
		if (count) [theParameters setObject:[count stringValue] forKey:@"count"];
		if (page) [theParameters setObject:[page stringValue] forKey:@"page"];
		
		self.twitterMethod = method;
		self.parameters = theParameters;
	}
	return self;
}

- (void) dealloc {
	[messages release];
	[timelineName release];
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
