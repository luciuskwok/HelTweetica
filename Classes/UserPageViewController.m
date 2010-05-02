    //
//  UserPageViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "UserPageViewController.h"
#import "LKWebView.h"
#import "Twitter.h"
#import "TwitterUser.h"



@implementation UserPageViewController
@synthesize webView, followButton, directMessageButton, currentPopover, twitter, user;


- (id)initWithTwitter:(Twitter*)aTwitter user:(TwitterUser*)aUser {
	self = [super initWithNibName:@"UserPage" bundle:nil];
	if (self) {
		self.twitter = aTwitter;
		self.user = aUser;
	}
	return self;
}

- (void)dealloc {
	[webView release];
	[followButton release];
	[directMessageButton release];

	[currentPopover release];
	
	[twitter release];
	[user release];

	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark HTML

- (NSString*)userInfoHTML {
	
	// Create custom page header with user info and set timeline to user's tweeets
	NSMutableString *html = [NSMutableString string];
	[html appendFormat: @"<img src='%@' align=left>", user.profileImageURL];
	[html appendFormat: @"screenName: %@<br> ", user.screenName];
	if (user.fullName) 
		[html appendFormat: @"fullName: %@<br> ", user.fullName];
	if (user.bio) 
		[html appendFormat: @"description: %@<br> ", user.bio];
	if (user.location) 
		[html appendFormat: @"location: %@<br> ", user.location];
	if (user.webURL) 
		[html appendFormat: @"web: %@<br> ", user.webURL];
	[html appendFormat: @"Follows %@ ", user.friendsCount];
	[html appendFormat: @"Followers %@ ", user.followersCount];
	[html appendFormat: @"Tweets %@ ", user.statusesCount];
	[html appendFormat: @"Favorites %@<br> ", user.favoritesCount];
	
	[html appendFormat: @"Joined %@<br> ", user.createdAt];
	
	if (user.protectedUser) 
		[html appendString: @"<img src=lock.png> Protected "];
	if (user.verifiedUser) 
		[html appendString: @"<img src=verified.png> Verified "];
	return html;
}

- (void)reloadWebView {
	// Use boilerplate header.html and footer.html
	
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSURL *baseURL = [NSURL fileURLWithPath:mainBundle];
	
	// Header
	NSError *error = nil;
	NSString *headerHTML = [NSString stringWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"header.html"] encoding:NSUTF8StringEncoding error:&error];
	if (error != nil) {
		NSLog (@"Error loading header.html: %@", [error localizedDescription]);
	}
	NSMutableString *html = [[NSMutableString alloc] initWithString:headerHTML];

	// Artboard and tweet area divs
	[html appendString:@"<div class='artboard'><div class='tweet_area'>"];

	// User info
	[html appendString: [self userInfoHTML]];
	
	// Close tweet area div.
	[html appendString:@"</div>"];

	// Footer (which closes artboard div)
	error = nil;
	NSString *footerHTML = [NSString stringWithContentsOfFile:[mainBundle stringByAppendingPathComponent:@"footer.html"] encoding:NSUTF8StringEncoding error:&error];
	if (error != nil) {
		NSLog (@"Error loading footer.html: %@", [error localizedDescription]);
	}
	[html appendString:footerHTML];
	
	[self.webView loadHTMLString:html baseURL:baseURL];
	[html release];
}

#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];
	
	[self reloadWebView];
}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.webView = nil;
	self.followButton = nil;
	self.directMessageButton = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}



#pragma mark IBActions

- (IBAction)close:(id)sender {
	//[self closeAllPopovers];
	[self.navigationController popViewControllerAnimated: YES];
}

- (IBAction)follow:(id)sender {
}

- (IBAction)directMessage:(id)sender {
}


@end
