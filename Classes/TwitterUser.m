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


@implementation TwitterUser
@synthesize identifier, screenName, fullName, bio, location, profileImageURL, webURL, friendsCount, followersCount, statusesCount, favoritesCount, createdAt, updatedAt, protectedUser, verifiedUser;
@synthesize statuses, favorites, lists, listSubscriptions;


- (id)init {
	self = [super init];
	if (self) {
		self.statuses = [NSMutableArray array];
		self.favorites = [NSMutableArray array];
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

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.identifier = [decoder decodeObjectForKey:@"identifier"];
		
		self.screenName = [decoder decodeObjectForKey:@"screenName"];
		self.fullName = [decoder decodeObjectForKey:@"fullName"];
		self.bio = [decoder decodeObjectForKey:@"bio"];
		self.location = [decoder decodeObjectForKey:@"location"];
		self.profileImageURL = [decoder decodeObjectForKey:@"profileImageURL"];
		self.webURL = [decoder decodeObjectForKey:@"webURL"];
		
		self.friendsCount = [decoder decodeObjectForKey:@"friendsCount"];
		self.followersCount = [decoder decodeObjectForKey:@"followersCount"];
		self.statusesCount = [decoder decodeObjectForKey:@"statusesCount"];
		self.favoritesCount = [decoder decodeObjectForKey:@"favoritesCount"];
		
		self.createdAt = [decoder decodeObjectForKey:@"createdAt"];
		self.updatedAt = [decoder decodeObjectForKey:@"updatedAt"];
		
		protectedUser = [decoder decodeBoolForKey:@"protectedUser"];
		verifiedUser = [decoder decodeBoolForKey:@"verifiedUser"];
		
		self.statuses = [self mutableArrayForKey:@"statuses" coder:decoder];
		self.favorites = [self mutableArrayForKey:@"favorites" coder:decoder];
		self.lists = [NSMutableArray array];
		self.listSubscriptions = [NSMutableArray array];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: identifier forKey:@"identifier"];
	
	[encoder encodeObject:screenName forKey:@"screenName"];
	[encoder encodeObject:fullName forKey:@"fullName"];
	[encoder encodeObject:bio forKey:@"bio"];
	[encoder encodeObject:location forKey:@"location"];
	[encoder encodeObject:profileImageURL forKey:@"profileImageURL"];
	[encoder encodeObject:webURL forKey:@"webURL"];
	
	[encoder encodeObject:friendsCount forKey:@"friendsCount"];
	[encoder encodeObject:followersCount forKey:@"followersCount"];
	[encoder encodeObject:statusesCount forKey:@"statusesCount"];
	[encoder encodeObject:favoritesCount forKey:@"favoritesCount"];
	
	[encoder encodeObject:createdAt forKey:@"createdAt"];
	[encoder encodeObject:updatedAt forKey:@"updatedAt"];
	
	[encoder encodeBool:protectedUser forKey:@"protectedUser"];
	[encoder encodeBool:verifiedUser forKey:@"verifiedUser"];

	[encoder encodeObject:[NSKeyedArchiver archivedDataWithRootObject:statuses] forKey:@"statuses"];
	[encoder encodeObject:[NSKeyedArchiver archivedDataWithRootObject:favorites] forKey:@"favorites"];
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
			self.protectedUser = flag;
		} else if ([key isEqualToString:@"verified"]) {
			self.verifiedUser = flag;
		}
	}
	
	// Other values are usually taken from elsewhere, for example: the user dictionary embedded in the status update in timelines.
}

@end
