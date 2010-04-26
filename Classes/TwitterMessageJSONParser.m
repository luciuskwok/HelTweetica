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


@interface TwitterMessageJSONParser (PrivateMethods)
- (void) parseJSONText:(NSString*)text startingAtOffset:(unsigned int)offset;
- (unsigned int) parseValueWithJSONText:(NSString*)text startingAtOffset:(unsigned int)offset;
- (unsigned int) parseKeyWithJSONText:(NSString*)text startingAtOffset:(unsigned int)offset;
@end

@implementation TwitterMessageJSONParser
@synthesize messages, currentMessage, keyPath, directMessage, receivedTimestamp;

+ (void) runTest {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"json"];
	NSError *error = nil;
	NSData *testJSON = [NSData dataWithContentsOfFile:path options:0 error:&error];
	TwitterMessageJSONParser *parser = [[TwitterMessageJSONParser alloc] init];
	[parser messagesWithJSONData:testJSON];
	[parser release];
}

- (id) init {
	if (self = [super init]) {
		messages = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	[messages release];
	[currentMessage release];
	[keyPath release];
	[receivedTimestamp release];
	[super dealloc];
}

- (NSArray*) messagesWithJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
	return [[messages retain] autorelease];
}

- (TwitterMessage*) currentRetweetedMessage {
	if (currentMessage == nil) return nil;
	if (currentMessage.retweetedMessage == nil) 
		currentMessage.retweetedMessage = [[[TwitterMessage alloc] init] autorelease];
	return currentMessage.retweetedMessage;
}

#pragma mark -
// LKJSONParser delegate methods

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	if (keyPath == nil) {
		self.keyPath = @"/";
	} else {
		if ([keyPath hasSuffix:@"/"] == NO)
			self.keyPath = [keyPath stringByAppendingString:@"/"];
	}
	
	if ([keyPath isEqualToString:@"/"]) {
		self.currentMessage = [[[TwitterMessage alloc] init] autorelease];
		currentMessage.direct = directMessage;
		currentMessage.receivedDate = receivedTimestamp;
	}
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath substringToIndex: keyPath.length - 1];
	} else {
		self.keyPath = [keyPath stringByDeletingLastPathComponent];
	}
	
	if ([keyPath isEqualToString:@"/"]) {
		if (currentMessage != nil) {
			[messages addObject: currentMessage];
			self.currentMessage = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
}

- (void) parser:(LKJSONParser*)parser foundKey:(NSString*)key {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath stringByAppendingPathComponent:key];
	} else {
		NSString *base = [keyPath stringByDeletingLastPathComponent];
		self.keyPath = [base stringByAppendingPathComponent:key];
	}
}

- (void) parserFoundNullValue:(LKJSONParser*)parser {
}

- (void) setBool:(BOOL) value forKeyPath:(NSString*)aKeyPath withMessage:(TwitterMessage*)message {
	if ([aKeyPath isEqualToString:@"/favorited"]) {
		message.favorite = value;
	} else if ([aKeyPath isEqualToString:@"/user/protected"] || [keyPath isEqualToString:@"/sender/protected"]) {
		[message setLocked: value];
	}
}

- (void) parser:(LKJSONParser*)parser foundBoolValue:(BOOL)value {
	if ([keyPath hasPrefix: @"retweeted_status/"]) {
		// Retweeted messages
		[self setBool:value forKeyPath:[keyPath substringFromIndex: 17] withMessage:[self currentRetweetedMessage]];
	} else {
		// Normal status message
		[self setBool:value forKeyPath:keyPath withMessage:currentMessage];
	}
}

- (void) setNumber:(NSNumber*) number forKeyPath:(NSString*)aKeyPath withMessage:(TwitterMessage*)message {
	if ([aKeyPath isEqualToString:@"/id"]) {
		message.identifier = number;
	} else if ([aKeyPath isEqualToString:@"/in_reply_to_status_id"]) {
		message.inReplyToStatusIdentifier = number;
	} else if ([aKeyPath isEqualToString:@"/in_reply_to_user_id"]) {
		message.inReplyToUserIdentifier = number;
	}
}

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	SInt64 x = 0;
	[[NSScanner scannerWithString:value] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];
	
	if ([keyPath hasPrefix: @"/retweeted_status/"]) {
		// Retweeted messages
		[self setNumber:number forKeyPath:[keyPath substringFromIndex: 17] withMessage:[self currentRetweetedMessage]];
	} else {
		// Normal status message
		[self setNumber:number forKeyPath:keyPath withMessage:currentMessage];
	}
}

- (NSDate*) dateWithTwitterStatusString: (NSString*) string {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"EEE MMM dd HH:mm:ss ZZ yyyy"]; // Mon Jan 25 00:46:47 +0000 2010
	NSDate *result = [formatter dateFromString:string];
	[formatter release];
	return result;
}

- (void) setValue:(NSString*) value forKeyPath:(NSString*)aKeyPath withMessage:(TwitterMessage*)message {
	if ([aKeyPath isEqualToString:@"/in_reply_to_screen_name"]) {
		message.inReplyToScreenName = value;
	} else if ([aKeyPath isEqualToString:@"/source"]) {
		message.source = value;
	} else if ([aKeyPath isEqualToString:@"/created_at"]) {
		message.createdDate = [self dateWithTwitterStatusString:value];
	} else if ([aKeyPath isEqualToString:@"/text"]) {
		message.content = value;
	} else if ([aKeyPath isEqualToString:@"/user/screen_name"] || [keyPath isEqualToString:@"/sender/screen_name"]) { 
		message.screenName = value;
	} else if ([aKeyPath isEqualToString:@"/user/profile_image_url"] || [keyPath isEqualToString:@"/sender/profile_image_url"]) { 
		message.avatar = value;
	}
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([keyPath hasPrefix: @"/retweeted_status/"]) {
		// Retweeted messages
		[self setValue:value forKeyPath:[keyPath substringFromIndex: 17] withMessage:[self currentRetweetedMessage]];
	} else {
		// Normal status message
		[self setValue:value forKeyPath:keyPath withMessage:currentMessage];
	}
}

@end
