//
//  TwitterUser.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TwitterUser : NSObject {
	
	NSNumber *identifier; // User ID
	
	NSString *screenName;
	NSString *description; // Bio
	NSString *location; // Location
	NSString *profileImageURL; // 48 x 48 avatar
	NSString *webURL; // User-entered Web URL
	
	NSNumber *friendsCount; // People user is following
	NSNumber *followersCount; // People who follow user
	NSNumber *statusesCount;
	NSNumber *favoritesCount;
	
	NSDate *createdAt; // Join date
	
	BOOL protectedUser; // Protected (lock icon)
	BOOL verifiedUser;
	// There is a "following" flag but it only applies to the authenticating user who requested the stream, so it depends on the account being used. There should be some way of caching the social graph of who follows whom.
}

@property (nonatomic, retain) NSNumber *identifier;

@property (nonatomic, retain) NSString *screenName;
@property (nonatomic, retain) NSString *description;
@property (nonatomic, retain) NSString *location;
@property (nonatomic, retain) NSString *profileImageURL;
@property (nonatomic, retain) NSString *webURL;

@property (nonatomic, retain) NSNumber *friendsCount;
@property (nonatomic, retain) NSNumber *followersCount;
@property (nonatomic, retain) NSNumber *statusesCount;
@property (nonatomic, retain) NSNumber *favoritesCount;

@property (nonatomic, retain) NSDate *createdAt;

@property (nonatomic, assign) BOOL protectedUser;
@property (nonatomic, assign) BOOL verifiedUser;

@end
