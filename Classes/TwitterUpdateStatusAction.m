//
//  TwitterUpdateStatusAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterUpdateStatusAction.h"


@implementation TwitterUpdateStatusAction

- (id) initWithText:(NSString*)text inReplyTo:(NSNumber*)replyTo {
	if (self = [super init]) {
		self.twitterMethod = @"statuses/update";
		
		NSMutableDictionary *theParameters = [NSMutableDictionary dictionary];
		[theParameters setObject:text forKey:@"status"];
		if (replyTo) 
			[theParameters setObject:[replyTo stringValue] forKey:@"in_reply_to_status_id"];
		self.parameters = theParameters;
	}
	return self;
}

- (void) start {
	[self startPostRequest];
}

@end
