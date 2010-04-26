//
//  TwitterRetweetAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterRetweetAction.h"


@implementation TwitterRetweetAction

- (id) initWithMessageIdentifier:(NSNumber*)identifier {
	if (self = [super init]) {
		self.twitterMethod = [NSString stringWithFormat:@"statuses/retweet/%@", identifier];
	}
	return self;
}

- (void) start {
	[self startPostRequest];
}



@end
