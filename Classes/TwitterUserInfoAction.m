//
//  TwitterUserInfoAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/7/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterUserInfoAction.h"
#import "TwitterUser.h"
#import "TwitterMessage.h"
#import "LKJSONParser.h"


@implementation TwitterUserInfoAction
@synthesize userResult, latestStatus, valid;

- (id)initWithScreenName:(NSString*)screenName {
	self = [super init];
	if (self) {
		self.twitterMethod =@"users/show";
		[parameters setObject:screenName forKey:@"screen_name"];	
	}
	return self;
}

- (void) dealloc {
	[userResult release];
	[latestStatus release];
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

#pragma mark Keys

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	if ([parser.keyPath isEqualToString:@"/"]) {
		self.userResult = [[[TwitterUser alloc] init] autorelease];
	} else if ([parser.keyPath isEqualToString:@"/status/"]) {
		self.latestStatus = [[[TwitterMessage alloc] init] autorelease];
	} else if ([parser.keyPath isEqualToString:@"/status/retweeted_status/"]) {
		self.latestStatus.retweetedMessage = [[[TwitterMessage alloc] init] autorelease];
	}
}

#pragma mark Values

- (void) foundValue:(id)value forKeyPath:(NSString*)keyPath {
	if ([keyPath hasPrefix:@"/status/retweeted_status"]) {
		if (self.latestStatus) 
			[self.latestStatus.retweetedMessage setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/status"]) {
		[self.latestStatus setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/"]) {
		[self.userResult setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} 

}

- (void) parser:(LKJSONParser*)parser foundBoolValue:(BOOL)value {
	[self foundValue: [NSNumber numberWithBool:value] forKeyPath:parser.keyPath];
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	[self foundValue: value forKeyPath:parser.keyPath];
}

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	[self foundValue: value forKeyPath:parser.keyPath];
}

@end
