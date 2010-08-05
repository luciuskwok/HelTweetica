//
//  TwitterAccount.h
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


#import <Foundation/Foundation.h>

@class TwitterStatusUpdate, TwitterTimeline, TwitterDirectMessageTimeline, LKSqliteDatabase;


@interface TwitterAccount : NSObject {
	// Core account info. Saved in user defaults.
	NSNumber *identifier;
	NSString *screenName;
	NSString *xAuthToken;
	NSString *xAuthSecret;
	
	// Cached data. References to sqlite db.
	TwitterTimeline *homeTimeline;
	TwitterTimeline *mentions;
	TwitterDirectMessageTimeline *directMessages;
	TwitterTimeline *favorites;
	NSMutableArray *lists;
	NSMutableArray *listSubscriptions;
	NSMutableArray *savedSearches;
}
@property (nonatomic, retain) NSNumber *identifier;
@property (nonatomic, retain) NSString *screenName;
@property (nonatomic, assign) NSString *password;
@property (nonatomic, retain) NSString *xAuthToken;
@property (nonatomic, retain) NSString *xAuthSecret;

@property (nonatomic, retain) TwitterTimeline *homeTimeline;
@property (nonatomic, retain) TwitterTimeline *mentions;
@property (nonatomic, retain) TwitterDirectMessageTimeline *directMessages;
@property (nonatomic, retain) TwitterTimeline *favorites;
@property (nonatomic, retain) NSMutableArray *lists;
@property (nonatomic, retain) NSMutableArray *listSubscriptions;
@property (nonatomic, retain) NSMutableArray *savedSearches;

- (void)setDatabase:(LKSqliteDatabase *)db;
- (void)synchronizeExisting:(NSMutableArray*)existingLists withNew:(NSArray*)newLists;
- (void)addFavorites:(NSArray*)set;
- (void)removeFavorite:(NSNumber *)message;
- (BOOL)messageIsFavorite:(NSNumber *)message;
- (void)deleteStatusUpdate:(NSNumber*)anIdentifier;

- (void)deleteCaches;

@end
