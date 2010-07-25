//
//  TwitterUser.h
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

#import <Foundation/Foundation.h>

@class TwitterTimeline;


@interface TwitterUser : NSObject {
	
	NSNumber *identifier; // User ID
	
	NSString *screenName;
	NSString *fullName;
	NSString *bio; // Bio
	NSString *location; // Location
	NSString *profileImageURL; // 48 x 48 avatar
	NSString *webURL; // User-entered Web URL
	
	NSNumber *friendsCount; // People user is following
	NSNumber *followersCount; // People who follow user
	NSNumber *statusesCount;
	NSNumber *favoritesCount;
	
	NSDate *createdAt; // Join date
	NSDate *updatedAt; // Creation date of status update that encapsulated this user info, or the date the info was received.
	
	BOOL protectedUser; // Protected (lock icon)
	BOOL verifiedUser;
	// There is a "following" flag but it only applies to the authenticating user who requested the stream, so it depends on the account being used. There should be some way of caching the social graph of who follows whom.
	
	// Fields that are not saved via NSCoder
	TwitterTimeline *statuses;
	TwitterTimeline *favorites;
	NSMutableArray *lists;
	NSMutableArray *listSubscriptions;
	
}

@property (nonatomic, retain) NSNumber *identifier;

@property (nonatomic, retain) NSString *screenName;
@property (nonatomic, retain) NSString *fullName;
@property (nonatomic, retain) NSString *bio;
@property (nonatomic, retain) NSString *location;
@property (nonatomic, retain) NSString *profileImageURL;
@property (nonatomic, retain) NSString *webURL;

@property (nonatomic, retain) NSNumber *friendsCount;
@property (nonatomic, retain) NSNumber *followersCount;
@property (nonatomic, retain) NSNumber *statusesCount;
@property (nonatomic, retain) NSNumber *favoritesCount;

@property (nonatomic, retain) NSDate *createdAt;
@property (nonatomic, retain) NSDate *updatedAt;

@property (nonatomic, assign) BOOL protectedUser;
@property (nonatomic, assign) BOOL verifiedUser;

@property (nonatomic, retain) TwitterTimeline *statuses;
@property (nonatomic, retain) TwitterTimeline *favorites;
@property (nonatomic, retain) NSMutableArray *lists;
@property (nonatomic, retain) NSMutableArray *listSubscriptions;

- (void) setValue:(id)value forTwitterKey:(NSString*)key;
- (BOOL) isNewerThan:(TwitterUser*)aUser;

@end
