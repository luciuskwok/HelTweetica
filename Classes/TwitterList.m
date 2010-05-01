//
//  TwitterList.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/9/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterList.h"


@implementation TwitterList
@synthesize name, username, fullName, description, slug, identifier, memberCount, statuses, privateList;

- (void) dealloc {
	[name release];
	[username release];
	[fullName release];
	[description release];
	[slug release];
	[identifier release];
	[memberCount release];
	[statuses release];
	[super dealloc];
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.name = [decoder decodeObjectForKey:@"name"];
		self.username = [decoder decodeObjectForKey:@"username"];
		self.description = [decoder decodeObjectForKey:@"description"];
		self.slug = [decoder decodeObjectForKey:@"slug"];

		self.identifier = [decoder decodeObjectForKey:@"identifier"];
		self.memberCount = [decoder decodeObjectForKey:@"memberCount"];

		privateList = [decoder decodeBoolForKey:@"privateList"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: name forKey:@"name"];
	[encoder encodeObject: username forKey:@"username"];
	[encoder encodeObject: description forKey:@"description"];
	[encoder encodeObject: slug forKey:@"slug"];
	
	[encoder encodeObject:identifier forKey:@"identifier"];
	[encoder encodeObject:memberCount forKey:@"memberCount"];
	
	[encoder encodeBool:privateList forKey:@"privateList"];
}

- (NSString*) description {
	return [NSString stringWithFormat: @"\"%@\" (%@): %@", name, slug, description];
}


@end
