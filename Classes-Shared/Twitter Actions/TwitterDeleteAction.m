//
//  TwitterDeleteAction.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 8/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterDeleteAction.h"


@implementation TwitterDeleteAction
@synthesize identifier;

- (id) initWithMessageIdentifier:(NSNumber*)anIdentifier {
	if (self = [super init]) {
		self.identifier = anIdentifier;
		self.twitterMethod = [NSString stringWithFormat:@"statuses/destroy/%@", anIdentifier];
	}
	return self;
}

- (void) start {
	[self startPostRequest];
}

@end
