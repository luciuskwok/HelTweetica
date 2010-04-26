//
//  TwitterFavoriteAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterFavoriteAction.h"


@implementation TwitterFavoriteAction
@synthesize message;


- (id) initWithMessage:(TwitterMessage*)aMessage destroy:(BOOL)flag {
	if (self = [super init]) {
		self.message = aMessage;
		destroy = flag;
		self.twitterMethod = [NSString stringWithFormat:@"favorites/%@/%@",  destroy ?@"destroy" : @"create", message.identifier];
	}
	return self;
}

- (void) start {
	[self startPostRequest];
}

- (void) parseReceivedData:(NSData*)data {
	// Ignore data and just set the message's favorite flag if the status is good or is 403, which indicates that the message is already set to the status we want.
	if ((statusCode < 400) || (statusCode == 403)) {
		message.favorite = !destroy;
	}
}


@end
