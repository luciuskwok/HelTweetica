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
@synthesize identifier, screenName, description, location, profileImageURL, webURL, friendsCount, followersCount, statusesCount, favoritesCount, createdAt, protectedUser, verifiedUser;

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.identifier = [decoder decodeObjectForKey:@"identifier"];
		
		self.screenName = [decoder decodeObjectForKey:@"screenName"];
		self.description = [decoder decodeObjectForKey:@"description"];
		self.location = [decoder decodeObjectForKey:@"location"];
		self.profileImageURL = [decoder decodeObjectForKey:@"profileImageURL"];
		self.webURL = [decoder decodeObjectForKey:@"webURL"];
		
		self.friendsCount = [decoder decodeObjectForKey:@"friendsCount"];
		self.followersCount = [decoder decodeObjectForKey:@"followersCount"];
		self.statusesCount = [decoder decodeObjectForKey:@"statusesCount"];
		self.favoritesCount = [decoder decodeObjectForKey:@"favoritesCount"];
		
		self.createdAt = [decoder decodeObjectForKey:@"createdAt"];
		
		protectedUser = [decoder decodeBoolForKey:@"protectedUser"];
		verifiedUser = [decoder decodeBoolForKey:@"verifiedUser"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: identifier forKey:@"identifier"];
	
	[encoder encodeObject:screenName forKey:@"screenName"];
	[encoder encodeObject:description forKey:@"description"];
	[encoder encodeObject:location forKey:@"location"];
	[encoder encodeObject:profileImageURL forKey:@"profileImageURL"];
	[encoder encodeObject:webURL forKey:@"webURL"];
	
	[encoder encodeObject:friendsCount forKey:@"friendsCount"];
	[encoder encodeObject:followersCount forKey:@"followersCount"];
	[encoder encodeObject:statusesCount forKey:@"statusesCount"];
	[encoder encodeObject:favoritesCount forKey:@"favoritesCount"];
	
	[encoder encodeObject:createdAt forKey:@"createdAt"];
	
	[encoder encodeBool:protectedUser forKey:@"protectedUser"];
	[encoder encodeBool:verifiedUser forKey:@"verifiedUser"];
}

- (void)dealloc {
	[identifier release];
	
	[screenName release];
	[description release];
	[location release];
	[profileImageURL release];
	[webURL release];
	
	[friendsCount release];
	[followersCount release];
	[statusesCount release];
	[favoritesCount release];
	
	[createdAt release];

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


@end
