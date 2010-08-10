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
#import "TwitterDirectMessageTimeline.h"
#import "TwitterStatusUpdate.h"
#import "TwitterLoadTimelineAction.h"
#import "TwitterList.h"

#ifndef TARGET_PROJECT_MAC
#import "SFHFKeychainUtils.h"
#endif


@implementation TwitterAccount
@synthesize identifier, screenName, xAuthToken, xAuthSecret;
@synthesize homeTimeline, mentions, directMessages, favorites, lists, listSubscriptions, savedSearches;

- (id)init {
	// Initialize a blank account
	self = [super init];
	if (self) {
		self.homeTimeline = [[[TwitterTimeline alloc] init] autorelease];
		homeTimeline.account = self;
		homeTimeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/home_timeline"] autorelease];

		self.mentions = [[[TwitterTimeline alloc] init] autorelease];
		mentions.account = self;
		mentions.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/mentions"] autorelease];
		
		self.directMessages = [[[TwitterDirectMessageTimeline alloc] init] autorelease];
		directMessages.account = self;
		// TwitterDirectMessageTimeline sets its own load action.
		
		self.favorites = [[[TwitterTimeline alloc] init] autorelease];
		favorites.account = self;
		favorites.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
		// Favorites always loads 20 per page. Cannot change the count.
		
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
	[directMessages release];
	[favorites release];
	[lists release];
	[listSubscriptions release];
	[savedSearches release];
	
	[super dealloc];
}

#pragma mark Public methods

- (void)setTwitter:(Twitter *)twttr {
	// Timelines will not work unless they have been given a database and table name.
	NSString *idString = [identifier stringValue];
	if (idString.length == 0) {
		// If the account identifier is empty, that means that login failed, so don't create tables.
		NSLog (@"User identifier is an empty string. Database tables were not created.");
		return;
	}

	[homeTimeline setTwitter:twttr tableName:[NSString stringWithFormat:@"User_%@_HomeTimeline", idString] temp:NO];
	[mentions setTwitter:twttr tableName:[NSString stringWithFormat:@"User_%@_Mentions", idString] temp:NO];
	[directMessages setTwitter:twttr tableName:[NSString stringWithFormat:@"User_%@_DirectMessages", idString] temp:NO];
	directMessages.accountIdentifier = identifier;
	[favorites setTwitter:twttr tableName:[NSString stringWithFormat:@"User_%@_Favorites", idString] temp:NO];
}

- (void)reloadNewer {
	// Refresh the home, mentions, and direct message timelines only. The favorites, lists, and search timelines will need to be manually refreshed.
	[self.homeTimeline reloadNewer];
	[self.mentions reloadNewer];
	[self.directMessages reloadNewer];
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

- (void)deleteStatusUpdate:(NSNumber*)anIdentifier {
	[homeTimeline removeIdentifier:anIdentifier];
	[mentions removeIdentifier:anIdentifier];
	[favorites removeIdentifier:anIdentifier];
	
	TwitterList *list;
	for (list in lists) {
		[list.statuses removeIdentifier:anIdentifier];
	}
	for (list in listSubscriptions) {
		[list.statuses removeIdentifier:anIdentifier];
	}
}

			
#pragma mark Password


#ifdef TARGET_PROJECT_MAC
// Mac OS Keychain
static const char *kKeychainServiceName = "HelTweetica";

- (void)removePassword {
	const char *cUser = [screenName cStringUsingEncoding:NSUTF8StringEncoding];
	SecKeychainItemRef keychainItemRef;
	
	// Remove any existing password for this username and replace it with new password.
	OSStatus err = SecKeychainFindGenericPassword(nil, strlen(kKeychainServiceName), kKeychainServiceName, strlen(cUser), cUser, nil, nil, &keychainItemRef);
	if (err == noErr) {
		err = SecKeychainItemDelete (keychainItemRef);
		if (err != noErr)
			NSLog (@"SecKeychainItemDelete() error: %d", err);
	}
}

- (NSString *)password {
	const char *cUser = [screenName cStringUsingEncoding:NSUTF8StringEncoding];
	void *cPass = nil;
	UInt32 length = 0;
	OSStatus err = SecKeychainFindGenericPassword(nil, strlen(kKeychainServiceName), kKeychainServiceName, strlen(cUser), cUser, &length, &cPass, nil);
	if (err != noErr)
		NSLog (@"SecKeychainFindGenericPassword () error: %d", err);
	
	NSString *string = [[[NSString alloc] initWithBytes:cPass length:length encoding:NSUTF8StringEncoding] autorelease];
	
	SecKeychainItemFreeContent (nil, cPass);
	if (err != noErr)
		NSLog (@"SecKeychainItemFreeContent() error %d.", err);
	
	return string;
}

- (void)setPassword:(NSString *)aPassword {
	// Remove any existing password for this username and replace it with new password.
	[self removePassword];
	
	const char *cUser = [screenName cStringUsingEncoding:NSUTF8StringEncoding];
	const char *cPass = [aPassword cStringUsingEncoding:NSUTF8StringEncoding];
	OSStatus err = SecKeychainAddGenericPassword(nil, strlen(kKeychainServiceName), kKeychainServiceName, strlen(cUser), cUser, strlen(cPass), cPass, nil);
	if (err != noErr)
		NSLog (@"SecKeychainAddGenericPassword() error: %d", err);
}

#else
// iPhone OS Keychain

static NSString *kKeychainServiceName = @"com.felttip.HelTweetica";

- (void)removePassword {
	[SFHFKeychainUtils deleteItemForUsername:screenName andServiceName:kKeychainServiceName error:nil];
}

- (NSString *)password {
	return [SFHFKeychainUtils getPasswordForUsername:screenName andServiceName:kKeychainServiceName error:nil];
}

- (void)setPassword:(NSString *)aPassword {
	[SFHFKeychainUtils storeUsername:screenName andPassword:aPassword forServiceName:kKeychainServiceName updateExisting:YES error:nil];
}

#endif

- (void)deleteCaches {
	[homeTimeline deleteCaches];
	[mentions deleteCaches];
	[directMessages deleteCaches];
	[favorites deleteCaches];
	[self removePassword];
}

@end
