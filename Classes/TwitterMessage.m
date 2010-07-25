//
//  Message.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/1/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterMessage.h"




@implementation TwitterMessage
@synthesize identifier, inReplyToStatusIdentifier, inReplyToUserIdentifier;
@synthesize screenName, inReplyToScreenName, avatar, content, source, retweetedMessage;
@synthesize createdDate, receivedDate;
@synthesize locked, favorite, direct;


- (void) dealloc {
	[identifier release];
	[inReplyToStatusIdentifier release];
	[inReplyToUserIdentifier release];
	[screenName release];
	[inReplyToScreenName release];
	[avatar release];
	[content release];
	[source release];
	[retweetedMessage release];
	[createdDate release];
	[receivedDate release];
	
	[super dealloc];
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.identifier = [decoder decodeObjectForKey:@"identifier"];
		self.inReplyToStatusIdentifier = [decoder decodeObjectForKey:@"inReplyToStatusIdentifier"];
		self.inReplyToUserIdentifier = [decoder decodeObjectForKey:@"inReplyToUserIdentifier"];
		
		self.screenName = [decoder decodeObjectForKey:@"username"];
		self.inReplyToScreenName = [decoder decodeObjectForKey:@"inReplyToScreenName"];
		self.avatar = [decoder decodeObjectForKey:@"avatar"];
		self.content = [decoder decodeObjectForKey:@"content"];
		self.source = [decoder decodeObjectForKey:@"source"];
		self.retweetedMessage = [decoder decodeObjectForKey:@"retweetedMessage"];
		
		self.createdDate = [decoder decodeObjectForKey:@"date"];
		self.receivedDate = [decoder decodeObjectForKey:@"receivedDate"];
		
		locked = [decoder decodeBoolForKey:@"locked"];
		favorite = [decoder decodeBoolForKey:@"favorite"];
		direct = [decoder decodeBoolForKey:@"direct"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: identifier forKey:@"identifier"];
	[encoder encodeObject: inReplyToStatusIdentifier forKey:@"inReplyToStatusIdentifier"];
	[encoder encodeObject: inReplyToUserIdentifier forKey:@"inReplyToUserIdentifier"];

	[encoder encodeObject:screenName forKey:@"username"];
	[encoder encodeObject:inReplyToScreenName forKey:@"inReplyToScreenName"];
	[encoder encodeObject:avatar forKey:@"avatar"];
	[encoder encodeObject:content forKey:@"content"];
	[encoder encodeObject:source forKey:@"source"];
	[encoder encodeObject:retweetedMessage forKey:@"retweetedMessage"];
	
	[encoder encodeObject:createdDate forKey:@"date"];
	[encoder encodeObject:receivedDate forKey:@"receivedDate"];
	
	[encoder encodeBool:locked forKey:@"locked"];
	[encoder encodeBool:favorite forKey:@"favorite"];
	[encoder encodeBool:direct forKey:@"direct"];
}

// description: for the debugger po command.
- (NSString*) description {
	NSMutableString *result = [NSMutableString string];
	if (screenName != nil) 
		[result appendFormat:@"%@: ", screenName];
	if (content != nil) 
		[result appendString: content];
	return result;
}

// hash and isEqual: are used by NSSet to determine if an object is unique.
- (NSUInteger) hash {
	return [identifier hash];
}

- (BOOL) isEqual:(id)object {
	BOOL result = NO;
	if ([object respondsToSelector:@selector(identifier)]) {
		result = [self.identifier isEqual: [object identifier]];
	}
	return result;
}

#pragma mark Twitter API

- (NSDate*) dateWithTwitterStatusString: (NSString*) string {
	// Twitter and Search use two different date formats, which differ by a comma at character 4.
	NSString *template;
	if ([string characterAtIndex:3] == ',') {
		// Twitter Search API format
		template = @"EEE, dd MMM yyyy HH:mm:ss ZZ"; // Mon, 25 Jan 2010 00:46:47 +0000 
	} else {
		// Twitter API default format
		template = @"EEE MMM dd HH:mm:ss ZZ yyyy"; // Mon Jan 25 00:46:47 +0000 2010
	}
	
	NSString *localeIdentifier = [NSLocale canonicalLocaleIdentifierFromString:@"en_US"];
	NSLocale *usLocale = [[[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier] autorelease];
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale: usLocale];
	[formatter setDateFormat:template];
	
	NSDate *result = [formatter dateFromString:string];
	return result;
}

- (NSNumber *)scanInt64FromString:(NSString *)string {
	SInt64 x = 0;
	[[NSScanner scannerWithString:string] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];
	return number;
}

// Given a key from the JSON data returned by the Twitter API, put the value in the appropriate ivar.
- (void) setValue:(id)value forTwitterKey:(NSString*)key {
	// String and number values
	if ([value isKindOfClass:[NSString class]]) {
		if ([key isEqualToString:@"in_reply_to_screen_name"]) {
			self.inReplyToScreenName = value;
		} else if ([key isEqualToString:@"source"]) {
			self.source = value;
		} else if ([key isEqualToString:@"text"]) {
			self.content = value;
		} else if ([key isEqualToString:@"id"]) {
			self.identifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"in_reply_to_status_id"]) {
			self.inReplyToStatusIdentifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"in_reply_to_user_id"]) {
			self.inReplyToUserIdentifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"created_at"]) {
			self.createdDate = [self dateWithTwitterStatusString:value];
		}
	}
	
	// Boolean values
	if ([value isKindOfClass:[NSNumber class]]) {
		BOOL flag = [value boolValue];
		if ([key isEqualToString:@"favorited"]) {
			self.favorite = flag;
		}
	}
	
	// Other values are usually taken from elsewhere, for example: the user dictionary embedded in the status update in timelines.
}
@end
