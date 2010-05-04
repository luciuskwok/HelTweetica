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
#import "HelTweeticaAppDelegate.h"
#import "WebBrowserViewController.h"

#import "TwitterLoadTimelineAction.h"



@implementation UserPageViewController
@synthesize followButton, user;


- (id)initWithTwitter:(Twitter*)aTwitter user:(TwitterUser*)aUser {
	self = [super initWithNibName:@"UserPage" bundle:nil];
	if (self) {
		self.user = aUser;
		
		// Limit number of tweets to request for user or list.
		self.defaultLoadCount = @"50";
		
	}
	return self;
}

- (void)dealloc {
	[followButton release];
	
	[user release];

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
	NSString *bio = user.bio ? user.bio : @"";
	
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

	return html;
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

#pragma mark View lifecycle

- (void)viewDidLoad {
 	if (user.screenName == nil)
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");

	// Download the latest tweets from this user.
	[self selectUserTimeline:user.screenName];
	[self reloadCurrentTimeline];

	[super viewDidLoad];
	//screenNameButton.title = user.screenName;

}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.followButton = nil;
	//self.directMessageButton = nil;
}

#pragma mark IBActions

- (IBAction)close:(id)sender {
	[self closeAllPopovers];
	[self.navigationController popViewControllerAnimated: YES];
}

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
}

#pragma mark User timeline
// TODO: needs to fold in RTs

- (void)selectUserTimeline:(NSString*)screenName {
	if (screenName == nil) {
		NSLog (@"-[UserPageViewController selectUserTimeline:] screenName should not be nil.");
		return;
	}
	
	self.customPageTitle = @"";
	self.currentTimeline = self.user.statuses;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/user_timeline"] autorelease];
	[currentTimelineAction.parameters setObject:screenName forKey:@"id"];
	[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"count"];
}

- (void)selectFavoritesTimeline:(NSString*)screenName {
	if (screenName == nil) return;
	
	self.customPageTitle = [NSString stringWithFormat:@"%@&rsquo;s <b>favorites</b>"];
	self.currentTimeline = self.user.favorites;
	self.currentTimelineAction = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"favorites"] autorelease];
	[currentTimelineAction.parameters setObject:screenName forKey:@"id"];
	// Favorites always loads 20 per page. Cannot change the count.
	//[currentTimelineAction.parameters setObject:defaultLoadCount forKey:@"count"];
}

- (void)didReloadCurrentTimeline:(TwitterLoadTimelineAction *)action {
	[super didReloadCurrentTimeline:action];
	
	// Update user object with latest version.
	TwitterUser *aUser = [twitter userWithScreenName:self.user.screenName];
	if (aUser != nil) {
		// Switch to instance of TwitterUser from the shared twitter instance.
		if (self.user != aUser) {
			self.user = aUser;
			self.user.statuses = aUser.statuses;
			self.user.favorites = aUser.favorites;
		}
		
		// Rewrite user_area div
		[self.webView setDocumentElement:@"user_info_area" innerHTML:[self userInfoHTML]];
	}
}


#pragma mark Web view delegate methods

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	if ([[url scheme] isEqualToString:@"action"]) {
		//TwitterAccount *account = [twitter currentAccount];
		NSString *actionName = [url resourceSpecifier];
		
		// Tabs
		if ([actionName isEqualToString:@"user"]) { // Home Timeline
			[self selectUserTimeline:user.screenName];
			[self reloadCurrentTimeline];
			return NO;
		} else if ([actionName isEqualToString:@"favorites"]) { // Favorites
			[self selectFavoritesTimeline:user.screenName];
			[self reloadCurrentTimeline];
			return NO;
		}
	}
	
	return [super webView:aWebView shouldStartLoadWithRequest:request navigationType:navigationType];
}


@end
