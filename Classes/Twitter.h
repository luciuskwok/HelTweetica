//
//  Twitter.h
//  HelTweetica
//
//  Created by Lucius Kwok on 3/30/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>
#import "TwitterMessage.h"
#import "TwitterAccount.h"


@interface Twitter : NSObject {
	NSArray *accounts;
	TwitterAccount *currentAccount;
	
	NSSet *statuses;
	NSMutableArray *actions;
	
	NSURLConnection *downloadConnection;
	NSInteger downloadStatusCode;
	NSMutableData *downloadData;
	SEL downloadCompleteAction;
	BOOL isLoading;
}

@property (nonatomic, retain) NSArray *accounts;
@property (nonatomic, retain) TwitterAccount *currentAccount;
@property (nonatomic, retain) NSSet *statuses;
@property (nonatomic, retain) NSURLConnection *downloadConnection;
@property (nonatomic, retain) NSMutableData *downloadData;
@property (assign) BOOL isLoading;

- (void) loginAccountWithScreenName:(NSString*)aScreenName password:(NSString*)aPassword;
- (void) addAccount: (TwitterAccount*) anAccount;
- (void) removeAccountAtIndex:(int)index;
- (void) moveAccountAtIndex:(int)fromIndex toIndex:(int)toIndex;

- (void) updateStatus:(NSString*)text inReplyTo:(NSNumber*)messageIdentifier;
- (void) fave:(NSNumber*)messageIdentifier;
- (void) retweet:(NSNumber*)messageIdentifier;

- (void) reloadHomeTimeline;
- (void) reloadMentions;
- (void) reloadDirectMessages;

- (void) loadHomeTimelineWithCount: (int) aCount olderThan:(NSNumber*) aMaxID newerThan:(NSNumber*) aSinceID;
- (void) loadMentionsWithCount: (int) aCount olderThan:(NSNumber*) aMaxID newerThan:(NSNumber*) aSinceID;
- (void) loadDirectMessagesWithCount: (int) aCount olderThan:(NSNumber*) aMaxID newerThan:(NSNumber*) aSinceID;
- (void) loadFavoritesWithUser:(NSString*)userOrNil page:(int)page;

- (void) loadListsWithUser:(NSString*)user;
- (void) loadListSubscriptionsWithUser:(NSString*)user;

- (void) loadSavedSearches;

- (void) cancel;

- (TwitterMessage*) statusWithIdentifier:(NSNumber*)identifier;

- (void) saveAccounts;

@end
