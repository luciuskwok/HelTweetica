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
#import "TwitterList.h"
#import "TwitterAction.h"

@class TwitterLoadTimelineAction;
@protocol TwitterDelegate;

@interface Twitter : NSObject <TwitterActionDelegate> {
	NSMutableArray *accounts;
	TwitterAccount *currentAccount;
	NSMutableArray *currentTimeline;
	TwitterAction *currentTimelineAction;
	
	NSMutableSet *statuses;
	NSMutableArray *actions;
	
	int defaultTimelineLoadCount;
	
	id <TwitterDelegate> delegate;
}

@property (nonatomic, retain) NSMutableArray *accounts;
@property (nonatomic, retain) TwitterAccount *currentAccount;
@property (nonatomic, retain) NSMutableArray *currentTimeline;
@property (nonatomic, retain) TwitterAction *currentTimelineAction;

@property (assign) id <TwitterDelegate> delegate;

- (void) loginScreenName:(NSString*)aScreenName password:(NSString*)aPassword;
- (void) moveAccountAtIndex:(int)fromIndex toIndex:(int)toIndex;

- (void) updateStatus:(NSString*)text inReplyTo:(NSNumber*)messageIdentifier;
- (void) fave:(NSNumber*)messageIdentifier;
- (void) retweet:(NSNumber*)messageIdentifier;

- (void) reloadCurrentTimeline;
- (void) selectHomeTimeline;
- (void) selectMentions;
- (void) selectDirectMessages;
- (void) selectFavorites;
- (void) selectTimelineOfList:(TwitterList*)list;
- (void) selectSearchTimelineWithQuery:(NSString*)query;
- (BOOL) isLoading;

- (TwitterMessage*) statusWithIdentifier:(NSNumber*)identifier;

- (void) saveAccounts;

@end

@protocol TwitterDelegate <NSObject>
- (void)twitter:(Twitter*)aTwitter willLoadTimelineWithName:(NSString*)name tabName:(NSString*)tabName;
- (void)twitter:(Twitter*)aTwitter didFinishLoadingTimeline:(NSArray*)aTimeline;
- (void)twitter:(Twitter*)aTwitter favoriteDidChange:(TwitterMessage*)aMessage;
- (void)twitterDidRetweet:(Twitter*)aTwitter;

- (void)twitter:(Twitter*)aTwitter didFailWithNetworkError:(NSError*)anError;
@end
