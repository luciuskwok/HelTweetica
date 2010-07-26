//
//  TwitterJsonParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterMessageJSONParser.h"
#import "TwitterMessage.h"
#import "TwitterUser.h"


@implementation TwitterMessageJSONParser
@synthesize messages, favorites, users;
@synthesize currentMessage, currentUser, currentRetweetedMessage, currentRetweetedUser;
@synthesize directMessage, receivedTimestamp;

- (id) init {
	if (self = [super init]) {
		messages = [[NSMutableArray alloc] init];
		favorites = [[NSMutableSet alloc] init];
		users = [[NSMutableSet alloc] init];
	}
	return self;
}

- (void) dealloc {
	[messages release];
	[favorites release];
	[users release];
	
	[currentMessage release];
	[currentUser release];
	[currentRetweetedMessage release];
	[currentRetweetedUser release];
	
	[receivedTimestamp release];
	[super dealloc];
}

- (void) parseJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
}

#pragma mark Keys

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	NSString *key = parser.keyPath;
	
	// Statuses
	if ([key isEqualToString:@"/"]) {
		self.currentMessage = [[[TwitterMessage alloc] init] autorelease];
		currentMessage.direct = directMessage;
		currentMessage.receivedDate = receivedTimestamp;
	} else if ([key isEqualToString:@"/user/"] || [key isEqualToString:@"/sender/"]) {
		self.currentUser = [[[TwitterUser alloc] init] autorelease];
	}
	
	// Retweets
	if ([key isEqualToString:@"/retweeted_status/"]) {
		self.currentRetweetedMessage = [[[TwitterMessage alloc] init] autorelease];
		currentRetweetedMessage.receivedDate = receivedTimestamp;
	} else if ([key isEqualToString:@"/retweeted_status/user/"]) {
		self.currentRetweetedUser = [[[TwitterUser alloc] init] autorelease];
	} 
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	NSString *key = parser.keyPath;
	
	// Statuses
	if ([key isEqualToString:@"/"]) {
		if (currentMessage) {
			// This line depends on the last currentUser to be left over after its dictionary is closed:
			if (currentUser)
				currentUser.updatedAt = currentMessage.createdDate;
			
			// Add object to messages array and set currentMessage to nil so that next object doesn't affect the closed message.
			[messages addObject: currentMessage];
			self.currentMessage = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	} else if ([key isEqualToString:@"/user"] || [key isEqualToString:@"/sender"]) {
		// Fill out message fields that are inside the user dictionary
		if (currentUser) {
			if (currentMessage) {
				// Some fields that this app stores in the message are in the JSON stream in the embedded user's dictionary.
				currentMessage.userScreenName = currentUser.screenName;
				currentMessage.profileImageURL = currentUser.profileImageURL;
				currentMessage.locked = currentUser.locked;
			}
			
			// Add to users set.
			[users addObject:currentUser];
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
	
	// Retweets
	if ([key isEqualToString:@"/retweeted_status"]) {
		if (currentRetweetedMessage != nil) {
			// This line depends on the last currentRetweetedUser to be left over after its dictionary is closed:
			if (currentRetweetedUser)
				currentRetweetedUser.updatedAt = currentRetweetedMessage.createdDate;
			
			// Add retweeted message to the currentMessage's retweetedMessage ivar.
			currentMessage.retweetedMessage = currentRetweetedMessage;
			self.currentRetweetedMessage = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	} else if ([key isEqualToString:@"/retweeted_status/user"]) {
		// Fill out message fields that are inside the user dictionary
		if (currentRetweetedUser) {
			if (currentRetweetedMessage) {
				// Some fields that this app stores in the message are in the JSON stream in the embedded user's dictionary.
				currentRetweetedMessage.userScreenName = currentRetweetedUser.screenName;
				currentRetweetedMessage.profileImageURL = currentRetweetedUser.profileImageURL;
				currentRetweetedMessage.locked = currentRetweetedUser.locked;
			}
			
			// Add to users set.
			[users addObject: currentRetweetedUser];
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
}

#pragma mark Values

- (void) foundValue:(id)value forKeyPath:(NSString*)keyPath {
	if ([keyPath hasPrefix:@"/user/"] || [keyPath hasPrefix:@"/sender/"]) {
		[self.currentUser setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/retweeted_status/user/"]) {
		[self.currentRetweetedUser setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/retweeted_status/"]) {
		[self.currentRetweetedMessage setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/recipient/"]) {
		// Ignore these key paths because they're only in DMs.
	} else if ([keyPath hasPrefix:@"/favorited/"]) {
		// Special handling for favorites. Instead of a flag in a message, which only is valid for the account requesting the favorite status, put the message in a set of favorites for this action.
		[favorites addObject:currentMessage];
	} else if ([keyPath hasPrefix:@"/"]) {
		[self.currentMessage setValue:value forTwitterKey:[keyPath lastPathComponent]];
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
