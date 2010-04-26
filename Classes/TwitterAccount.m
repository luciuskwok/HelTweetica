//
//  TwitterAccount.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/8/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterAccount.h"
#import "TwitterMessage.h"
#import "TwitterList.h"


@implementation TwitterAccount
@synthesize screenName, xAuthToken, xAuthSecret, timeline, mentions, directMessages, favorites, lists, listSubscriptions, savedSearches;

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.screenName = [decoder decodeObjectForKey:@"screenName"];
		self.xAuthToken = [decoder decodeObjectForKey:@"xAuthToken"];
		self.xAuthSecret = [decoder decodeObjectForKey:@"xAuthSecret"];
		
		self.timeline = [NSKeyedUnarchiver unarchiveObjectWithData:[decoder decodeObjectForKey: @"timeline"]];
		self.mentions = [NSKeyedUnarchiver unarchiveObjectWithData:[decoder decodeObjectForKey: @"mentions"]];
		self.directMessages = [NSKeyedUnarchiver unarchiveObjectWithData:[decoder decodeObjectForKey: @"directMessages"]];
		self.favorites = [NSKeyedUnarchiver unarchiveObjectWithData:[decoder decodeObjectForKey: @"favorites"]];

		self.lists = [NSKeyedUnarchiver unarchiveObjectWithData:[decoder decodeObjectForKey: @"lists"]];
		self.listSubscriptions = [NSKeyedUnarchiver unarchiveObjectWithData:[decoder decodeObjectForKey: @"listSubscriptions"]];
			
		self.savedSearches = [NSKeyedUnarchiver unarchiveObjectWithData:[decoder decodeObjectForKey: @"savedSearches"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: screenName forKey:@"screenName"];
	[encoder encodeObject: xAuthToken forKey:@"xAuthToken"];
	[encoder encodeObject: xAuthSecret forKey:@"xAuthSecret"];
	
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:timeline] forKey: @"timeline"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:mentions] forKey: @"mentions"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:directMessages] forKey: @"directMessages"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:favorites] forKey: @"favorites"];

	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:lists] forKey: @"lists"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:listSubscriptions] forKey: @"listSubscriptions"];

	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:savedSearches] forKey: @"savedSearches"];
}

- (void) dealloc {
	[screenName release];
	[xAuthToken release];
	[xAuthSecret release];
	[timeline release];
	[mentions release];
	[directMessages release];
	[favorites release];
	[lists release];
	[listSubscriptions release];
	[savedSearches release];
	[super dealloc];
}

#pragma mark -

- (NSSet*) setByAddingAllStatusesToSet: (NSSet*) set {
	NSMutableSet *newSet = [NSMutableSet setWithSet:set];
	[newSet addObjectsFromArray: timeline];
	[newSet addObjectsFromArray: mentions];
	[newSet addObjectsFromArray: favorites];
	return newSet;
}

- (void) removeStatusFromFavoritesWithIdentifier: (NSNumber*) identifier {
	// Removes all instances with matching identifier from favorites timeline
	NSMutableArray *newFavorites = [NSMutableArray arrayWithCapacity: favorites.count];
	
	for (TwitterMessage *message in favorites) {
		if ([message.identifier isEqualToNumber: identifier] == NO) {
			[newFavorites addObject: message];
		}
	}
	
	self.favorites = newFavorites;
}

@end
