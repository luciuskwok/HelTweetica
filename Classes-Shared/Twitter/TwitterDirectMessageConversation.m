//
//  TwitterDirectMessageConversation.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterDirectMessageConversation.h"


@implementation TwitterDirectMessageConversation
@synthesize userIdentifier, messages;

- (id)initWithUserIdentifier:(NSNumber *)identifier {
	self = [super init];
	if (self) {
		self.userIdentifier = identifier;
		messages = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc {
	[userIdentifier release];
	[messages release];
	[super dealloc];
}


	
@end
