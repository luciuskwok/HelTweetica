//
//  UserPageHTMLController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

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
		NSError *error = nil;
		NSString *filePath = [[NSBundle mainBundle] pathForResource:@"tweet-row-highlighted-template" ofType:@"html"];
		highlightedTweetRowTemplate = [[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error] retain];
		if (error != nil)
			NSLog (@"Error loading tweet-row-highlighted-template.html: %@", [error localizedDescription]);
	}
	return self;
}

- (void)dealloc {
	[user release];
	[highlightedTweetRowTemplate release];
	[super dealloc];
}


#pragma mark Timeline selection

- (void)selectUserTimeline:(NSString *)screenName {
	if (screenName == nil) {
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");
		return;
	}
	
	self.customPageTitle = nil;
	self.timeline = user.statuses;
	self.timeline.loadAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/user_timeline"] autorelease];
	[self.timeline.loadAction.parameters setObject:screenName forKey:@"id"];
	[self.timeline.loadAction.parameters setObject:defaultLoadCount forKey:@"count"];
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
		
		// Rewrite user_area div
		[self.webView setDocumentElement:@"user_info_area" innerHTML:[self userInfoHTML]];
	}
}

#pragma mark TwitterAction

- (void)loadUserInfo {
	TwitterUserInfoAction *action = [[[TwitterUserInfoAction alloc] initWithScreenName:user.screenName] autorelease];
	action.completionAction = @selector(didLoadUserInfo:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didLoadUserInfo:(id)action {
	// TODO: set user in Twitter singleton and in this class.
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
	NSError *error = nil;
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"user-page-template" ofType:@"html"];
	NSMutableString *html = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
	if (error != nil)
		NSLog (@"Error loading user-page-template.html: %@", [error localizedDescription]);

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
	NSMutableString *visibleText = [NSMutableString stringWithString:url];
	
	// Remove http[s]:// prefix
	if ([visibleText hasPrefix:@"http://"]) 
		[visibleText deleteCharactersInRange:NSMakeRange(0, 7)];
	else if ([visibleText hasPrefix:@"https://"])
		[visibleText deleteCharactersInRange:NSMakeRange(0, 8)];
	
	// Limit length
	if (visibleText.length > 35) {
		[visibleText replaceCharactersInRange:NSMakeRange(35, visibleText.length - 35) withString:@"..."];
	}
	
	return [NSString stringWithFormat:@"<a href='%@'>%@</a>", url, visibleText];
}	

- (NSString *)userInfoHTML {
	// Load HTML template and replace variables with values.
	
	// Load template
	NSError *error = nil;
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"user-info-template" ofType:@"html"];
	NSMutableString *html = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
	if (error != nil)
		NSLog (@"Error loading user-info-template.html: %@", [error localizedDescription]);
	
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
	
	NSString *joinDate = user.createdAt ? [self formattedDate:user.createdAt] : @"";
	
	NSString *protectedUser = user.protectedUser ? @"<img src=lock.png>" : @"";
	NSString *verifiedUser = user.verifiedUser ? @"<img src=verified.png class='user_verified'> Verified" : @"";
	
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
	[self replaceBlock:@"JoinDate" display:(user.createdAt != nil) inTemplate:html];
	
	return html;
}

- (NSString *)tweetRowTemplateForRow:(int)row {
	if (row == 0 && timeline == user.statuses)
		return highlightedTweetRowTemplate;
	return [super tweetRowTemplateForRow:row];
}

- (NSString*) tweetAreaFooterHTML {
	NSString *result = @"";
	
	if (unauthorized) {
		result = @"<div class='status'>Protected user.</div>";
	} else if (notFound) {
		result = @"<div class='status'>No such user.</div>";
	} else {
		result = [super tweetAreaFooterHTML];
	}
	return result;
}


@end
