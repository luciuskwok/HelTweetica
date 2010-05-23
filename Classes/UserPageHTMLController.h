//
//  UserPageHTMLController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TimelineHTMLController.h"
#import "TwitterUser.h"


@interface UserPageHTMLController : TimelineHTMLController {
	TwitterUser *user;
	BOOL unauthorized;
	BOOL notFound;
	NSString *highlightedTweetRowTemplate;
}
@property (nonatomic, retain) TwitterUser *user;

// Timeline selection
- (void)selectUserTimeline:(NSString *)screenName;
- (void)selectFavoritesTimeline:(NSString *)screenName;

// TwitterAction
- (void)loadUserInfo;
- (void)loadFriendStatus:(NSString*)screenName;
- (void)follow;
- (void)unfollow;

// HTML
- (NSString *)userInfoHTML;

@end


@protocol UserPageHTMLControllerDelegate <NSObject> 
- (void)didUpdateFriendshipStatusWithAccountFollowsUser:(BOOL)accountFollowsUser userFollowsAccount:(BOOL)userFollowsAccount;
@end
