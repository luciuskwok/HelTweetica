//
//  UserPageHTMLController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TimelineHTMLController.h"
@class TwitterUser;


@interface UserPageHTMLController : TimelineHTMLController {
	TwitterUser *user;
	BOOL unauthorized;
	BOOL notFound;
	NSString *highlightedTweetRowTemplate;
}
@property (nonatomic, retain) TwitterUser *user;

- (void)selectUserTimeline:(NSString*)screenName;

// HTML
- (NSString *)userInfoHTML;

@end
