//
//  UserPageHTMLController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UserPageHTMLController.h"

#import "TwitterLoadTimelineAction.h"
#import "TwitterFriendshipsAction.h"
#import "TwitterShowFriendshipsAction.h"
#import "TwitterUserInfoAction.h"


@implementation UserPageHTMLController
@synthesize user;

- (id)init {
	self = [super init];
	if (self) {
		// Special template to highlight the selected message. tweet-row-highlighted-template.html
		highlightedTweetRowTemplate = [[self loadHTMLTemplate:@"tweet-row-highlighted-template"] retain];
	}
	return self;
}

- (void)dealloc {
	[user release];
	[highlightedTweetRowTemplate release];
	[super dealloc];
}

- (void)setUser:(TwitterUser *)aUser {
	if (user != aUser) {
		[user release];
		user = [aUser retain];
	}
	
	// Set up database connection.
	[aUser setTimelineDatabase:twitter.database];
}

#pragma mark Timeline selection

- (void)selectUserTimeline:(NSString *)screenName {
	if (screenName == nil) {
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");
		return;
	}
	
	self.customPageTitle = nil;
	self.timeline = user.statuses;
	self.messages = [timeline statusUpdatesWithLimit: maxTweetsShown];
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/user_timeline"] autorelease];
	[self.timeline.loadAction.parameters setObject:screenName forKey:@"id"];
	[self loadTimeline: timeline];

	// Show loading spinner or old tweets
	[self rewriteTweetArea];
	
	// Notify delegate that a different timeline was selected.
	if ([delegate respondsToSelector:@selector(didSelectTimeline:)])
		[delegate didSelectTimeline:timeline];
}

- (void)selectFavoritesTimeline:(NSString *)screenName {
	if (screenName == nil) return;
	
	self.customPageTitle = [NSString stringWithFormat:@"%@&rsquo;s <b>favorites</b>", user.screenName];
	self.timeline = user.favorites;
	self.messages = [timeline statusUpdatesWithLimit: maxTweetsShown];
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	[self.timeline.loadAction.parameters setObject:screenName forKey:@"id"];
	// Favorites always loads 20 per page. Cannot change the count.
	[self loadTimeline: timeline];
	
	// Show loading spinner or old tweets
	[self rewriteTweetArea];
	
	// Notify delegate that a different timeline was selected.
	if ([delegate respondsToSelector:@selector(didSelectTimeline:)])
		[delegate didSelectTimeline:timeline];
	
}

- (void) timeline:(TwitterTimeline *)aTimeline didLoadWithAction:(TwitterLoadTimelineAction *)action {
	[super timeline:aTimeline didLoadWithAction:action];
	
	// Update user object with latest version.
	TwitterUser *aUser = [twitter userWithScreenName:self.user.screenName];
	if (aUser != nil) {
		// Switch to instance of TwitterUser from the shared twitter instance.
		self.user = aUser;
		[self rewriteUserInfoArea];
	}
}

- (void)rewriteUserInfoArea {
	[self.webView setDocumentElement:@"user_info_area" innerHTML:[self userInfoHTML]];
}

#pragma mark TwitterAction

- (void)loadUserInfo {
	TwitterUserInfoAction *action = [[[TwitterUserInfoAction alloc] initWithScreenName:user.screenName] autorelease];
	action.completionAction = @selector(didLoadUserInfo:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didLoadUserInfo:(TwitterUserInfoAction*)action {
	// Update existing record if it exists
	TwitterUser *existingUser = [twitter userWithIdentifier:action.userResult.identifier];
	if (existingUser) {
		[existingUser updateValuesWithUser:action.userResult];
		[twitter addUsers:[NSSet setWithObject:existingUser]];
	} else {
		[twitter addUsers:[NSSet setWithObject:action.userResult]];
	}
	[twitter addStatusUpdates:[NSArray arrayWithObjects: action.latestStatus, action.retweetedStatus, nil]];
	self.user = action.userResult;
	[self rewriteUserInfoArea];
}

- (void)loadFriendStatus:(NSString*)screenName {
	TwitterShowFriendshipsAction *action = [[[TwitterShowFriendshipsAction alloc] initWithTarget:screenName] autorelease];
	action.completionAction = @selector(didLoadFriendStatus:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didLoadFriendStatus:(TwitterShowFriendshipsAction *)action {
	if (action.valid) {
		id <UserPageHTMLControllerDelegate> userPageDelegate = (<UserPageHTMLControllerDelegate>) delegate;
		if ([userPageDelegate respondsToSelector:@selector(didUpdateFriendshipStatusWithAccountFollowsUser:userFollowsAccount:)])
			[userPageDelegate didUpdateFriendshipStatusWithAccountFollowsUser:action.sourceFollowsTarget userFollowsAccount:action.targetFollowsSource];
	}
}

- (void)follow {
	TwitterFriendshipsAction *action = [[[TwitterFriendshipsAction alloc] initWithScreenName:user.screenName create:YES] autorelease];
	action.completionAction = @selector(didFollow:);
	action.completionTarget = self;
	//suppressNetworkErrorAlerts = NO;
	[self startTwitterAction:action];
}

- (void)didFollow:(id)action {
	[self loadFriendStatus: user.screenName];
}

- (void)unfollow {
	TwitterFriendshipsAction *action = [[[TwitterFriendshipsAction alloc] initWithScreenName:user.screenName create:NO] autorelease];
	action.completionAction = @selector(didUnfollow:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didUnfollow:(id)action {
	[self loadFriendStatus: user.screenName];
}

- (void)handleTwitterStatusCode:(int)code {
	// For user pages, a status code of 401 indicates that the currentAccount isn't authorized to view this user's page
	switch (code) {
		case 401:
			unauthorized = YES;
			break;
		case 404:
			notFound = YES;
			break;
		default:
			[super handleTwitterStatusCode:code];
			break;
	}
	
	if (code >= 400) {
		[self invalidateRefreshTimer];
		[self rewriteTweetArea];
	}
}

#pragma mark HTML

- (NSString*) webPageTemplate {
	// Load main template
	NSMutableString *html = [NSMutableString stringWithString:[self loadHTMLTemplate:@"user-page-template"]];

	// Replace custom tags with HTML
	NSString *userInfoAreaHTML = [self userInfoHTML];
	[html replaceOccurrencesOfString:@"<userInfoAreaHTML/>" withString:userInfoAreaHTML options:0 range:NSMakeRange(0, html.length)];
	
	return html;
}

- (NSString*)formattedDate:(NSDate*)date {
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	[dateFormatter setDateStyle:NSDateFormatterLongStyle];
	return [dateFormatter stringFromDate:date];
}

- (NSString*)formattedNumber:(NSNumber*)number {
	NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
	[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
	return [formatter stringFromNumber:number];
}

- (NSString*)webURLHTML:(NSString*)url {
	return [self htmlFormattedString:url];
}	

- (NSString *)userInfoHTML {
	// Load HTML template and replace variables with values.
	if (user == nil) return @"";
	
	// Load template
	NSMutableString *html = [NSMutableString stringWithString:[self loadHTMLTemplate:@"user-info-template"]];
	
	// Prepare variables
	NSString *profileImageURL = @"profile-image-proxy.png";
	if (user.profileImageURL)
		profileImageURL = [user.profileImageURL stringByReplacingOccurrencesOfString:@"_normal" withString:@""];
	NSString *fullName = user.fullName ? user.fullName : @"";
	NSString *location = user.location ? user.location : @"";
	NSString *web = user.webURL ? [self webURLHTML:user.webURL] : @"";
	NSString *bio = user.bio ? [self htmlFormattedString: user.bio] : @"";
	
	NSString *friendsCount = user.friendsCount ? [self formattedNumber:user.friendsCount] : @"";
	NSString *followersCount = user.followersCount ? [self formattedNumber:user.followersCount] : @"";
	NSString *statusesCount = user.statusesCount ? [self formattedNumber:user.statusesCount] : @"";
	NSString *favoritesCount = user.favoritesCount ? [self formattedNumber:user.favoritesCount] : @"";
	
	NSString *joinDate = user.createdDate ? [self formattedDate:user.createdDate] : @"";
	
	NSString *protectedUser = user.locked ? @"<img src=lock.png>" : @"";
	NSString *verifiedUser = user.verified ? @"<img src=verified.png class='user_verified'> Verified" : @"";
	
	// Replace
	[html replaceOccurrencesOfString:@"{profileImageURL}" withString:profileImageURL options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{screenName}" withString:user.screenName options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{fullName}" withString:fullName options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{location}" withString:location options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{web}" withString:web options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{bio}" withString:bio options:0 range:NSMakeRange(0, html.length)];
	
	[html replaceOccurrencesOfString:@"{friendsCount}" withString:friendsCount options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{followersCount}" withString:followersCount options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{statusesCount}" withString:statusesCount options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{favoritesCount}" withString:favoritesCount options:0 range:NSMakeRange(0, html.length)];
	
	[html replaceOccurrencesOfString:@"{joinDate}" withString:joinDate options:0 range:NSMakeRange(0, html.length)];
	
	[html replaceOccurrencesOfString:@"{protectedUser}" withString:protectedUser options:0 range:NSMakeRange(0, html.length)];
	[html replaceOccurrencesOfString:@"{verifiedUser}" withString:verifiedUser options:0 range:NSMakeRange(0, html.length)];
	
	// Blocks
	[self replaceBlock:@"Name" display:(user.fullName.length != 0) inTemplate:html];
	[self replaceBlock:@"Location" display:(user.location.length != 0) inTemplate:html];
	[self replaceBlock:@"Web" display:(user.webURL.length != 0) inTemplate:html];
	[self replaceBlock:@"Bio" display:(user.bio.length != 0) inTemplate:html];
	[self replaceBlock:@"JoinDate" display:(user.createdDate != nil) inTemplate:html];
	
	return html;
}

- (NSString *)tweetRowTemplateForRow:(int)row {
	if (row == 0 && self.customPageTitle == nil)
		return highlightedTweetRowTemplate;
	return [super tweetRowTemplateForRow:row];
}

- (NSString*) tweetAreaFooterHTML {
	NSString *result = @"";
	
	if (user == nil) {
		result = @"<div class='status'>Type in a user name above.</div>";
	} else if (unauthorized) {
		result = @"<div class='status'>Protected user.</div>";
	} else if (notFound) {
		result = @"<div class='status'>No such user.</div>";
	} else {
		result = [super tweetAreaFooterHTML];
	}
	return result;
}


@end
