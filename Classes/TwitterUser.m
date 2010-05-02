//
//  TwitterUser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterUser.h"


@implementation TwitterUser
@synthesize identifier, screenName, description, location, profileImageURL, webURL, friendsCount, followersCount, statusesCount, favoritesCount, createdAt, protectedUser, verifiedUser;

- (void)dealloc {
	[identifier release];
	
	[screenName release];
	[description release];
	[location release];
	[profileImageURL release];
	[webURL release];
	
	[friendsCount release];
	[followersCount release];
	[statusesCount release];
	[favoritesCount release];
	
	[createdAt release];

	[super dealloc];
}


@end
