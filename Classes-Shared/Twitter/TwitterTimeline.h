//
//  TwitterTimeline.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
@class Twitter, TwitterAccount, TwitterLoadTimelineAction, TwitterAction, TwitterStatusUpdate;


// Notification constants
#define TwitterTimelineDidFinishLoadingNotification @"TwitterTimelineDidFinishLoadingNotification"
#define TwitterTimelineDidFinishLoadingGapNotification @"TwitterTimelineDidFinishLoadingGapNotification"


@interface TwitterTimeline : NSObject {
	Twitter *twitter;
	TwitterAccount *account;
	NSString *databaseTableName;
	BOOL noOlderMessages;
	TwitterLoadTimelineAction *loadAction;
	BOOL replaceExistingStatusUpdates;
	
	NSNumber *secondNewestIdentifier;
	NSNumber *latestReadIdentifier;
}
@property (nonatomic, assign) Twitter *twitter;
@property (nonatomic, assign) TwitterAccount *account;
@property (nonatomic, copy) NSString *databaseTableName;
@property (assign) BOOL noOlderMessages;
@property (nonatomic, retain) TwitterLoadTimelineAction *loadAction;
@property (assign) BOOL replaceExistingStatusUpdates;

@property (nonatomic, retain) NSNumber *secondNewestIdentifier;
@property (nonatomic, retain) NSNumber *latestReadIdentifier;


// Database
- (void)setTwitter:(Twitter *)aTwitter tableName:(NSString*)tableName temp:(BOOL)temp;
- (void)deleteCaches;
- (int)numberOfStatusUpdates;
- (void)limitDatabaseTableSize;

// Messages (Status Updates or Direct Messages)
- (void)addMessages:(NSArray*)messages;
- (void)removeIdentifier:(NSNumber *)identifier;
- (BOOL)containsIdentifier:(NSNumber *)identifier;
- (NSArray *)messagesWithLimit:(int)limit;
- (NSArray *)messagesSinceDate:(NSDate*)date;
- (NSNumber *)newestStatusIdentifier;

// Gap
- (BOOL)hasGapAfter:(NSNumber *)identifier;

// Loading from Twitter
- (void)reloadAll;
- (void)reloadNewer;
- (void)loadOlderWithMaxIdentifier:(NSNumber*)maxIdentifier;
- (void)didLoadOlderInCurrentTimeline:(TwitterLoadTimelineAction *)action;
- (int)defaultLoadCount;

@end


