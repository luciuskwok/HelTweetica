//
//  LoadSavedSearchesAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterLoadSavedSearchesAction.h"


@implementation TwitterLoadSavedSearchesAction
@synthesize queries, key;


- (id)init {
	self = [super init];
	if (self) {
		self.twitterMethod = @"saved_searches";
		self.queries = [NSMutableArray array];
	}
	return self;
}

- (void) dealloc {
	[queries release];
	[key release];
	[super dealloc];
}

- (void) start {
	[self startGetRequest];
}

- (void) parseReceivedData:(NSData*)data {
	if (statusCode < 400) {
		LKJSONParser *parser = [[LKJSONParser alloc] initWithData:data];
		parser.delegate = self;
		[parser parse];
		[parser release];
	}
}

- (void) parser:(LKJSONParser*)parser foundKey:(NSString*)aKey {
	self.key = aKey;
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([key isEqualToString:@"query"]) {
		[queries addObject:value];
	}
}


@end
