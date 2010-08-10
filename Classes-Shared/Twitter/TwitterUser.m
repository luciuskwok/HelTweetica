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
#import "NSDate+RelativeDate.h"
#import "NSString+HTMLFormatted.h"



@implementation TwitterUser
@synthesize identifier, screenName, fullName, bio, location, profileImageURL, webURL, friendsCount, followersCount, statusesCount, favoritesCount, createdDate, updatedDate, locked, verified;
@synthesize statuses, favorites, lists, listSubscriptions;


+ (NSArray *)databaseKeys {
	return [NSArray arrayWithObjects:@"identifier", @"createdDate", @"updatedDate", 
			@"screenName", @"fullName", @"bio", @"location", @"profileImageURL", @"webURL",
			@"friendsCount", @"followersCount", @"statusesCount", @"favoritesCount",
			@"locked", @"verified", nil];
}

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

- (id)initWithDictionary:(NSDictionary *)d {
	self = [self init];
	if (self) {
		self.identifier = [d objectForKey:@"identifier"];
		self.createdDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[d objectForKey:@"createdDate"] doubleValue]];
		self.updatedDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[d objectForKey:@"updatedDate"] doubleValue]];

		self.screenName = [d objectForKey:@"screenName"];
		self.fullName = [d objectForKey:@"fullName"];
		self.bio = [d objectForKey:@"bio"];
		self.location = [d objectForKey:@"location"];
		self.profileImageURL = [d objectForKey:@"profileImageURL"];
		self.webURL = [d objectForKey:@"webURL"];

		self.friendsCount = [d objectForKey:@"friendsCount"];
		self.followersCount = [d objectForKey:@"followersCount"];
		self.statusesCount = [d objectForKey:@"statusesCount"];
		self.favoritesCount = [d objectForKey:@"favoritesCount"];
		self.locked = [[d objectForKey:@"locked"] boolValue];
		self.verified = [[d objectForKey:@"verified"] boolValue];
	}
	return self;
}

- (void)dealloc {
	[identifier release];
	[createdDate release];
	[updatedDate release];
	
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
	
	[statuses release];
	[favorites release];
	[lists release];
	[listSubscriptions release];

	[super dealloc];
}

- (NSString*) description {
	// for the debugger po command.
	return screenName ? screenName : @"<no screen name>";
}

- (NSUInteger) hash {
	// hash and isEqual: are used by NSSet to determine if an object is unique.
	return [identifier hash];
}

- (BOOL) isEqual:(id)object {
	BOOL result = NO;
	if ([object respondsToSelector:@selector(identifier)]) {
		result = [self.identifier isEqual: [object identifier]];
	}
	return result;
}

#pragma mark Database

- (void)setTwitter:(Twitter *)aTwitter account:(TwitterAccount *)account {
	[statuses setTwitter:aTwitter tableName:[NSString stringWithFormat:@"User_%@_Statuses", screenName] temp:NO];
	[favorites setTwitter:aTwitter tableName:[NSString stringWithFormat:@"User_%@_Favorites", screenName] temp:NO];
	statuses.account = account;
	favorites.account = account;
}

- (id)databaseValueForKey:(NSString *)key {
	if ([key isEqualToString:@"locked"]) {
		return [NSNumber numberWithBool:self.locked];
	} else if ([key isEqualToString:@"verified"]) {
		return [NSNumber numberWithBool:self.verified];
	}
	return [self valueForKey:key];
}

#pragma mark Twitter API

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
			self.createdDate = [NSDate dateWithTwitterString:value];
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
	if (self.updatedDate == nil) return NO;
	if (aUser.updatedDate == nil) return YES;
	return ([self.updatedDate compare:aUser.updatedDate] == NSOrderedDescending);
}

- (void)updateValuesWithUser:(TwitterUser *)aUser {
	if (aUser.identifier)
		self.identifier = aUser.identifier;
	if (aUser.screenName)
		self.screenName = aUser.screenName;
	if (aUser.fullName)
		self.fullName = aUser.fullName;
	if (aUser.bio)
		self.bio = aUser.bio;
	if (aUser.location)
		self.location = aUser.location;
	if (aUser.profileImageURL)
		self.profileImageURL = aUser.profileImageURL;
	if (aUser.webURL)
		self.webURL = aUser.webURL;
	if (aUser.friendsCount)
		self.friendsCount = aUser.friendsCount;
	if (aUser.followersCount)
		self.followersCount = aUser.followersCount;
	if (aUser.statusesCount)
		self.statusesCount = aUser.statusesCount;
	if (aUser.favoritesCount)
		self.favoritesCount = aUser.favoritesCount;
	if (aUser.createdDate)
		self.createdDate = aUser.createdDate;
	if (aUser.updatedDate)
		self.updatedDate = aUser.updatedDate;
	self.locked = aUser.locked;
	self.verified =aUser.verified;
}

@end
