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
#import "TwitterTimeline.h"
#import "TwitterStatusUpdate.h"
#import "TwitterList.h"


@implementation TwitterAccount
@synthesize identifier, screenName, xAuthToken, xAuthSecret;
@synthesize homeTimeline, mentions, directMessagesReceived, directMessagesSent, favorites, lists, listSubscriptions, savedSearches;

- (id)init {
	// Initialize a blank account
	self = [super init];
	if (self) {
		self.homeTimeline = [[[TwitterTimeline alloc] init] autorelease];
		self.mentions = [[[TwitterTimeline alloc] init] autorelease];
		self.directMessagesReceived = [[[TwitterTimeline alloc] init] autorelease];
		self.directMessagesSent = [[[TwitterTimeline alloc] init] autorelease];
		self.favorites = [[[TwitterTimeline alloc] init] autorelease];
		self.lists = [NSMutableArray array];
		self.listSubscriptions = [NSMutableArray array];
	}
	return self;
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [self init]) {
		self.identifier = [decoder decodeObjectForKey:@"identifier"];
		self.screenName = [decoder decodeObjectForKey:@"screenName"];
		self.xAuthToken = [decoder decodeObjectForKey:@"xAuthToken"];
		self.xAuthSecret = [decoder decodeObjectForKey:@"xAuthSecret"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: identifier forKey:@"identifier"];
	[encoder encodeObject: screenName forKey:@"screenName"];
	[encoder encodeObject: xAuthToken forKey:@"xAuthToken"];
	[encoder encodeObject: xAuthSecret forKey:@"xAuthSecret"];
}

- (void) dealloc {
	[identifier release];
	[screenName release];
	[xAuthToken release];
	[xAuthSecret release];
	
	[homeTimeline release];
	[mentions release];
	[directMessagesReceived release];
	[directMessagesSent release];
	[favorites release];
	[lists release];
	[listSubscriptions release];
	[savedSearches release];
	
	[super dealloc];
}

#pragma mark Public methods

- (void)setDatabase:(LKSqliteDatabase *)db {
	// Timelines will not work unless they have been given a database and table name.
	NSString *idString = [identifier stringValue];
	if (idString.length == 0) {
		// If the account identifier is empty, that means that login failed, so don't create tables.
		NSLog (@"User identifier is an empty string. Database tables were not created.");
		return;
	}

	[homeTimeline setDatabase:db tableName:[NSString stringWithFormat:@"User_%@_HomeTimeline", idString] temp:NO];
	[mentions setDatabase:db tableName:[NSString stringWithFormat:@"User_%@_Mentions", idString] temp:NO];
	[directMessagesReceived setDatabase:db tableName:[NSString stringWithFormat:@"User_%@_DirectMessagesReceived", idString] temp:NO];
	[directMessagesSent setDatabase:db tableName:[NSString stringWithFormat:@"User_%@_DirectMessagesSent", idString] temp:NO];
	[favorites setDatabase:db tableName:[NSString stringWithFormat:@"User_%@_Favorites", idString] temp:NO];

}

- (void)synchronizeExisting:(NSMutableArray*)existingLists withNew:(NSArray*)newLists {
	NSSet *oldSet = [NSSet setWithArray: existingLists];
	
	// Remove all old objects and insert new objects, reusing old ones if they match.
	[existingLists removeAllObjects];
	int index;
	TwitterList *oldList, *newList;
	for (index = 0; index < newLists.count; index++) {
		newList = [newLists objectAtIndex: index];
		oldList = [oldSet member:newList]; // If the set of old lists includes an identical member from the new lists, replace the entry in the new lists with the old one.
		if (oldList)
			newList = oldList;
		newList.receivedDate = [NSDate date];
		[existingLists addObject: newList];
	}
}

- (void)addFavorites:(NSArray*)set {
	[favorites addMessages:set];
}

- (void)removeFavorite:(NSNumber *)messageIdentifier {
	[favorites removeIdentifier:messageIdentifier];
}

- (BOOL)messageIsFavorite:(NSNumber *)messageIdentifier {
	return [favorites containsIdentifier:messageIdentifier];
}
			
- (void)deleteCaches {
	[homeTimeline deleteCaches];
	[mentions deleteCaches];
	[directMessagesReceived deleteCaches];
	[directMessagesSent deleteCaches];
	[favorites deleteCaches];
}

@end
