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
#import "TwitterMessage.h"
#import "TwitterList.h"



@implementation TwitterAccount
@synthesize identifier, screenName, xAuthToken, xAuthSecret, homeTimeline, mentions, directMessages, favorites, lists, listSubscriptions, savedSearches;

- (id)init {
	// Initialize a blank account
	self = [super init];
	if (self) {
		self.homeTimeline = [[[TwitterTimeline alloc] init] autorelease];
		self.mentions = [[[TwitterTimeline alloc] init] autorelease];
		self.directMessages = [[[TwitterTimeline alloc] init] autorelease];
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

- (TwitterTimeline *)timelineForKey:(NSString *)key coder:(NSCoder *)decoder {
	TwitterTimeline *aTimeline = [decoder decodeObjectForKey:key];
	if ([aTimeline isKindOfClass: [TwitterTimeline class]]) {
		return aTimeline;
	}
	return [[[TwitterTimeline alloc] init] autorelease];
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.screenName = [decoder decodeObjectForKey:@"screenName"];
		self.xAuthToken = [decoder decodeObjectForKey:@"xAuthToken"];
		self.xAuthSecret = [decoder decodeObjectForKey:@"xAuthSecret"];
		
		self.homeTimeline = [self timelineForKey:@"homeTimeline" coder:decoder];
		self.mentions = [self timelineForKey:@"mentions" coder:decoder];
		self.directMessages = [self timelineForKey:@"directMessages" coder:decoder];
		self.favorites = [self timelineForKey:@"favorites" coder:decoder];

		self.lists = [self mutableArrayForKey:@"lists" coder:decoder];
		self.listSubscriptions = [self mutableArrayForKey:@"listSubscriptions" coder:decoder];
				
		self.savedSearches = [self mutableArrayForKey: @"savedSearches2" coder:decoder];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: screenName forKey:@"screenName"];
	[encoder encodeObject: xAuthToken forKey:@"xAuthToken"];
	[encoder encodeObject: xAuthSecret forKey:@"xAuthSecret"];
	
	[encoder encodeObject: homeTimeline forKey: @"homeTimeline"];
	[encoder encodeObject: mentions forKey: @"mentions"];
	[encoder encodeObject: directMessages forKey: @"directMessages"];
	[encoder encodeObject: favorites forKey: @"favorites"];

	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:lists] forKey: @"lists"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:listSubscriptions] forKey: @"listSubscriptions"];

	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:savedSearches] forKey: @"savedSearches2"];
}

- (void) dealloc {
	[screenName release];
	[xAuthToken release];
	[xAuthSecret release];
	
	[homeTimeline release];
	[mentions release];
	[directMessages release];
	[favorites release];
	
	[lists release];
	[listSubscriptions release];
	[savedSearches release];
	[super dealloc];
}

#pragma mark Public methods

- (void) removeStatusFromFavoritesWithIdentifier: (NSNumber*) anIdentifier {
	[self.favorites removeMessageWithIdentifier:anIdentifier];
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

- (void)addFavorites:(NSSet*)set {
	for (TwitterMessage *message in set) {
		if ([favorites.messages containsObject:message] == NO) 
			[favorites.messages addObject:message];
	}
}

@end
