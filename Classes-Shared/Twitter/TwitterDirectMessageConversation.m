//
//  TwitterDirectMessageConversation.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterDirectMessageConversation.h"


@implementation TwitterDirectMessageConversation
@synthesize user, messages;

- (void)dealloc {
	[user release];
	[messages release];
	[super dealloc];
}


	
@end
