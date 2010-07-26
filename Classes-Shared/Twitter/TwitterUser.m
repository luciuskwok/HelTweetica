//
//  TwitterUser.m
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

#import "TwitterUser.h"
#import "TwitterTimeline.h"



@implementation TwitterUser
@synthesize identifier, screenName, fullName, bio, location, profileImageURL, webURL, friendsCount, followersCount, statusesCount, favoritesCount, createdAt, updatedAt, locked, verified;
@synthesize statuses, favorites, lists, listSubscriptions;


- (id)init {
	self = [super init];
	if (self) {
		self.statuses = [[[TwitterTimeline alloc] init] autorelease];
		self.favorites = [[[TwitterTimeline alloc] init] autorelease];
		self.lists = [NSMutableArray array];
		self.listSubscriptions = [NSMutableArray array];
	}
	return self;
}

- (NSMutableArray*) mutableArrayForKey:(NSString *)key coder:(NSCoder *)decoder {
	NSData *data = [decoder decodeObjectForKey:key];
	NSMutableArray *array;
	if (data && [data isKindOfClass:[NSData class]]) {
		array = [NSMutableArray arrayWithArray: [NSKeyedUnarchiver unarchiveObjectWithData:data]];
	} else {
		array = [NSMutableArray array];
	}
	return array;
}

- (TwitterTimeline *)decodeTimelineForKey:(NSString *)key withDecoder:(NSCoder *)decoder {
	TwitterTimeline *aTimeline = [decoder decodeObjectForKey:key];
	if ([aTimeline isKindOfClass: [TwitterTimeline class]]) {
		return aTimeline;
	}
	return [[[TwitterTimeline alloc] init] autorelease];
}

- (void)dealloc {
	[identifier release];
	
	[screenName release];
	[fullName release];
	[bio release];
	[location release];
	[profileImageURL release];
	[webURL release];
	
	[friendsCount release];
	[followersCount release];
	[statusesCount release];
	[favoritesCount release];
	
	[createdAt release];
	[updatedAt release];
	
	[statuses release];
	[favorites release];
	[lists release];
	[listSubscriptions release];

	[super dealloc];
}

// description: for the debugger po command.
- (NSString*) description {
	return screenName ? screenName : @"<no screen name>";
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
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	if ([string characterAtIndex:3] == ',') {
		// Twitter Search API format
		[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZ"]; // Mon, 25 Jan 2010 00:46:47 +0000 
	} else {
		// Twitter API default format
		[formatter setDateFormat:@"EEE MMM dd HH:mm:ss ZZ yyyy"]; // Mon Jan 25 00:46:47 +0000 2010
	}
	NSDate *result = [formatter dateFromString:string];
	[formatter release];
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
		// Numbers
		if ([key isEqualToString:@"id"]) {
			self.identifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"friends_count"]) {
			self.friendsCount = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"followers_count"]) {
			self.followersCount = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"statuses_count"]) {
			self.statusesCount = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"favourites_count"]) {
			self.favoritesCount = [self scanInt64FromString:value];
		}
		
		// Strings
		if ([key isEqualToString:@"screen_name"]) {
			self.screenName = value;
		} else if ([key isEqualToString:@"name"]) {
			self.fullName = value;
		} else if ([key isEqualToString:@"description"]) {
			self.bio = value;
		} else if ([key isEqualToString:@"location"]) {
			self.location = value;
		} else if ([key isEqualToString:@"profile_image_url"]) {
			self.profileImageURL = value;
		} else if ([key isEqualToString:@"url"]) {
			self.webURL = value;
		} else if ([key isEqualToString:@"created_at"]) {
			self.createdAt = [self dateWithTwitterStatusString:value];
		}
	}
	
	// Boolean values
	if ([value isKindOfClass:[NSNumber class]]) {
		BOOL flag = [value boolValue];
		if ([key isEqualToString:@"protected"]) {
			self.locked = flag;
		} else if ([key isEqualToString:@"verified"]) {
			self.verified = flag;
		}
	}
	
	// Other values are usually taken from elsewhere, for example: the user dictionary embedded in the status update in timelines.
}

- (BOOL) isNewerThan:(TwitterUser*)aUser {
	if (self.updatedAt == nil) return NO;
	if (aUser.updatedAt == nil) return YES;
	return ([self.updatedAt compare:aUser.updatedAt] == NSOrderedDescending);
}


@end
