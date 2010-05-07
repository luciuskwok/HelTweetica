    //
//  UserPageViewController.m
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

#import "UserPageViewController.h"
#import "Twitter.h"
#import "TwitterUser.h"
#import "WebBrowserViewController.h"

#import "TwitterLoadTimelineAction.h"
#import "TwitterFriendshipsAction.h"
#import "TwitterShowFriendshipsAction.h"
#import "TwitterUserInfoAction.h"


// Tag used to identify Follow/Unfollow button in Toolbar
#define kFollowButtonTag 69
#define kFollowButtonPositionFromEnd 2


@implementation UserPageViewController
@synthesize topToolbar, user;


- (id)initWithTwitterUser:(TwitterUser*)aUser {
	self = [super initWithNibName:@"UserPage" bundle:nil];
	if (self) {
		self.user = aUser;
		self.defaultLoadCount = @"50"; // Limit number of tweets to request for user or list.
		maxTweetsShown = 400; // Allow for a larger limit for searches.
		
		// Special template to highlight the selected message. tweet-row-highlighted-template.html
		NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
		NSError *error = nil;
		highlightedTweetRowTemplate = [[NSString alloc] initWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"tweet-row-highlighted-template.html"] encoding:NSUTF8StringEncoding error:&error];
		if (error != nil)
			NSLog (@"Error loading tweet-row-highlighted-template.html: %@", [error localizedDescription]);
	}
	return self;
}

- (void)dealloc {
	[topToolbar release];
	[user release];
	[highlightedTweetRowTemplate release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark HTML

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

- (NSString*)userInfoHTML {
	// Load HTML template and replace variables with values.
	
	// Load
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSString *templateFile = [mainBundle stringByAppendingPathComponent:@"user-info-template.html"];
	NSError *error = nil;
	NSMutableString *html  = [NSMutableString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&error];
	
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
	if (row == 0 && self.currentTimeline == user.statuses)
		return highlightedTweetRowTemplate;
	return tweetRowTemplate;
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

- (NSString*) webPageTemplate {
	// Load main template
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSString *templateFile = [mainBundle stringByAppendingPathComponent:@"user-page-template.html"];
	NSError *error = nil;
	NSMutableString *html  = [NSMutableString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&error];
	
	// Replace custom tags with HTML
	NSString *userInfoAreaHTML = [self userInfoHTML];
	[html replaceOccurrencesOfString:@"<userInfoAreaHTML/>" withString:userInfoAreaHTML options:0 range:NSMakeRange(0, html.length)];
	
	return html;
}

#pragma mark TwitterActions

- (void)loadFriendStatus:(NSString*)screenName {
	TwitterShowFriendshipsAction *action = [[[TwitterShowFriendshipsAction alloc] initWithTarget:screenName] autorelease];
	action.completionAction = @selector(didLoadFriendStatus:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didLoadFriendStatus:(TwitterShowFriendshipsAction *)action {
	// Insert follow/unfollow button in toolbar
	
	SEL buttonAction = action.sourceFollowsTarget ? @selector(unfollow:) : @selector(follow:);
	NSString *buttonTitle = action.sourceFollowsTarget ? NSLocalizedString (@"Unfollow", @"button") : NSLocalizedString (@"Follow", @"button");
	NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:self.topToolbar.items];
	
	// Remove any existing Follow/Unfollow buttons
	int index;
	for (index = 0; index < toolbarItems.count; index++) {
		UIBarItem *item = [toolbarItems objectAtIndex:index];
		if (item.tag == kFollowButtonTag) {
			[toolbarItems removeObjectAtIndex:index];
			break;
		}
	}
	
	// Only add button if the friend status is valid
	if (action.valid && !	[currentAccount.screenName isEqualToString:user.screenName]) {
		index = toolbarItems.count - kFollowButtonPositionFromEnd; // Position two from end
		UIBarButtonItem *followButton = [[[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStyleBordered target:self action:buttonAction] autorelease];
		followButton.tag = kFollowButtonTag;
		[toolbarItems insertObject:followButton atIndex:index];
	}
	
	[topToolbar setItems:toolbarItems animated:YES];
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
		[refreshTimer invalidate];
		refreshTimer = nil;
		[self rewriteTweetArea];
	}
}


#pragma mark IBActions

- (IBAction) lists: (id) sender {
	if ([self closeAllPopovers] == NO) {
		ListsViewController *lists = [[[ListsViewController alloc] initWithAccount:currentAccount] autorelease];
		lists.screenName = self.user.screenName;
		lists.currentLists = self.user.lists;
		lists.currentSubscriptions = self.user.listSubscriptions;
		lists.delegate = self;
		[self presentContent: lists inNavControllerInPopoverFromItem: sender];
	}
}

- (IBAction)follow:(id)sender {
	TwitterFriendshipsAction *action = [[[TwitterFriendshipsAction alloc] initWithScreenName:user.screenName create:YES] autorelease];
	action.completionAction = @selector(didFollow:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didFollow:(id)action {
	[self loadFriendStatus: user.screenName];
}

- (IBAction)unfollow:(id)sender {
	TwitterFriendshipsAction *action = [[[TwitterFriendshipsAction alloc] initWithScreenName:user.screenName create:NO] autorelease];
	action.completionAction = @selector(didUnfollow:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didUnfollow:(id)action {
	[self loadFriendStatus: user.screenName];
}

#pragma mark User info loading

- (void) loadUserInfo {
	TwitterUserInfoAction *action = [[[TwitterUserInfoAction alloc] initWithScreenName:user.screenName] autorelease];
	action.completionAction = @selector(didLoadUserInfo:);
	action.completionTarget = self;
	[self startTwitterAction:action];
}

- (void)didLoadUserInfo:(id)action {
	// TODO: set user in Twitter singleton and in this class.
}


#pragma mark Timeline loading

- (void) reloadRetweetTimeline {
	if ([currentTimelineAction.twitterMethod isEqualToString:@"statuses/user_timeline"]) {
		/*
		NSString *method = nil;
		
		// if user is same as account, get my own retweets.
		// @"statuses/retweeted_by_me"
		
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/retweeted_by_me"] autorelease];
		[action.parameters setObject:defaultLoadCount forKey:@"count"];
		
		// Set the since_id parameter minimize the number of statuses requested
		if (currentTimeline.count > 0) {
			TwitterMessage *message = [currentTimeline objectAtIndex: 0]; 
			[action.parameters setObject:[message.identifier stringValue] forKey:@"since_id"];
		}
		
		// Prepare action and start it. 
		action.timeline = currentTimeline;
		action.completionTarget= self;
		action.completionAction = @selector(didReloadCurrentTimeline:);
		[self startTwitterAction:action];
		*/
	}
}

- (void)selectUserTimeline:(NSString*)screenName {
	if (screenName == nil) {
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");
		return;
	}
	
	self.customPageTitle = nil;
	self.currentTimeline = user.statuses;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/user_timeline"] autorelease];
	[currentTimelineAction.parameters setObject:screenName forKey:@"id"];
	[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"count"];
}

- (void)selectFavoritesTimeline:(NSString*)screenName {
	if (screenName == nil) return;
	
	self.customPageTitle = [NSString stringWithFormat:@"%@&rsquo;s <b>favorites</b>", user.screenName];
	self.currentTimeline = user.favorites;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	[currentTimelineAction.parameters setObject:screenName forKey:@"id"];
	// Favorites always loads 20 per page. Cannot change the count.
	//[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"count"];
}

- (void)didReloadCurrentTimeline:(TwitterLoadTimelineAction *)action {
	[super didReloadCurrentTimeline:action];
	
	// TODO: should use the user instance updated with the TwitterUserInfoAction, since it's the latest info, while user info from tweets is only as new as the latest tweet from that user.
	
	// Update user object with latest version.
	TwitterUser *aUser = [twitter userWithScreenName:self.user.screenName];
	if (aUser != nil) {
		// Switch to instance of TwitterUser from the shared twitter instance.
		self.user = aUser;
		
		// Rewrite user_area div
		[self.webView setDocumentElement:@"user_info_area" innerHTML:[self userInfoHTML]];
	}
}


#pragma mark Web view delegate methods

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	suppressNetworkErrorAlerts = NO;
	
	if ([[url scheme] isEqualToString:@"action"]) {
		//TwitterAccount *account = [twitter currentAccount];
		NSString *actionName = [url resourceSpecifier];
		
		// Tabs
		if ([actionName hasPrefix:@"user"]) { // Home Timeline
			NSString *screenName = [actionName lastPathComponent];
			if ([screenName caseInsensitiveCompare:user.screenName] == NSOrderedSame) {
				[self selectUserTimeline:user.screenName];
				[self startLoadingCurrentTimeline];
			} else {
				[self showUserPage:screenName];
			}
			return NO;
		} else if ([actionName isEqualToString:@"favorites"]) { // Favorites
			[self selectFavoritesTimeline:user.screenName];
			[self startLoadingCurrentTimeline];
			return NO;
		}
	}
	
	return [super webView:aWebView shouldStartLoadWithRequest:request navigationType:navigationType];
}


#pragma mark View lifecycle

- (void)viewDidLoad {
 	if (user.screenName == nil)
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");
	
	// Download the latest tweets from this user.
	[self selectUserTimeline:user.screenName];
	[self reloadCurrentTimeline];
	
	// Get the following/follower status, but only if it's a different user from the account.
	if ([currentAccount.screenName isEqualToString:user.screenName] == NO) 
		[self loadFriendStatus: user.screenName];
	
	// Get the latest user info
	[self loadUserInfo];
	
	[super viewDidLoad];
	//screenNameButton.title = user.screenName;
	
}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.topToolbar = nil;
	//self.directMessageButton = nil;
}

@end
