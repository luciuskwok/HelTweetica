//
//  TwitterSearchJSONParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TwitterSearchJSONParser.h"
#import "TwitterStatusUpdate.h"
#import "NSDate+RelativeDate.h"
#import "NSString+HTMLFormatted.h"


@implementation TwitterSearchJSONParser
@synthesize messages, currentMessage, receivedTimestamp;

- (id) init {
	if (self = [super init]) {
		messages = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	[messages release];
	[currentMessage release];
	[receivedTimestamp release];
	[super dealloc];
}

- (void) parseJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
}

#pragma mark -
// LKJSONParser delegate methods

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	if ([parser.keyPath isEqualToString:@"/results/"]) {
		self.currentMessage = [[[TwitterStatusUpdate alloc] init] autorelease];
		currentMessage.receivedDate = receivedTimestamp;
	}
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	if ([parser.keyPath isEqualToString:@"/results"]) {
		if (currentMessage != nil) {
			[messages addObject: currentMessage];
			self.currentMessage = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
}

// currentMessage.favorite needs an indeterminite state because search API doesn't return this info.

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	SInt64 x = 0;
	[[NSScanner scannerWithString:value] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];
	
	if ([parser.keyPath isEqualToString:@"/results/id"]) {
		currentMessage.identifier = number;
	} else if ([parser.keyPath isEqualToString:@"/results/from_user_id"]) {
		//currentMessage.inReplyToStatusIdentifier = number; // Search uses different user ID numbers than Twitter's main feed, so ignore them for now.
	} else if ([parser.keyPath isEqualToString:@"/results/to_user_id"]) {
		//currentMessage.inReplyToUserIdentifier = number;
	}
	
}

- (NSString *)stringReplacingAmpersandEscapes:(NSString *)string {
	NSMutableString *result = [NSMutableString stringWithString:string];
	[result replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([parser.keyPath isEqualToString:@"/results/to_user"]) {
		currentMessage.inReplyToScreenName = value;
	} else if ([parser.keyPath isEqualToString:@"/results/source"]) {
		currentMessage.source = [self stringReplacingAmpersandEscapes:value];
	} else if ([parser.keyPath isEqualToString:@"/results/created_at"]) {
		currentMessage.createdDate = [NSDate dateWithTwitterString:value];
	} else if ([parser.keyPath isEqualToString:@"/results/text"]) {
		currentMessage.text = value;
	} else if ([parser.keyPath isEqualToString:@"/results/from_user"]) { 
		currentMessage.userScreenName = value;
	} else if ([parser.keyPath isEqualToString:@"/results/profile_image_url"]) { 
		currentMessage.profileImageURL = value;
	}
}


@end
