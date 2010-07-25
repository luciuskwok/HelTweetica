//
//  TwitterShowFriendshipsAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TwitterShowFriendshipsAction.h"
#import "LKJSONParser.h"



@implementation TwitterShowFriendshipsAction
@synthesize sourceFollowsTarget, targetFollowsSource, valid;

- (id) initWithTarget:(NSString*)targetScreenName {
	if (self = [super init]) {
		self.twitterMethod =@"friendships/show";
		[parameters setObject:targetScreenName forKey:@"target_screen_name"];	
	}
	return self;
}

- (void) dealloc {
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
		valid = YES;
	}
}

- (void) parser:(LKJSONParser*)parser foundBoolValue:(BOOL)value {
	if ([parser.keyPath hasPrefix:@"/relationship/source/following"]) {
		sourceFollowsTarget = value;
	} else if ([parser.keyPath hasPrefix:@"/relationship/source/followed_by"]) {
		targetFollowsSource = value;
	}
}


@end
