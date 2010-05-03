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



@implementation UserPageViewController
@synthesize screenNameButton, followButton, directMessageButton, currentPopover, user;


- (id)initWithTwitter:(Twitter*)aTwitter user:(TwitterUser*)aUser {
	self = [super initWithNibName:@"UserPage" bundle:nil];
	if (self) {
		self.user = aUser;
		appDelegate = [[UIApplication sharedApplication] delegate];
		
		if ([aUser.identifier intValue] == -1) { // This means the user info needs to be loaded from Twitter
			
		}
		
		// Also download the latest tweets from this user.
	}
	return self;
}

- (void)dealloc {
	[screenNameButton release];
	[followButton release];
	[directMessageButton release];
	[currentPopover release];
	
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
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
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
	NSString *templateFile = [mainBundle stringByAppendingPathComponent:@"user-page-template.html"];
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

- (NSString*)tweetAreaHTML {
	NSMutableString *html = [NSMutableString string];
	
	// User info
	[html appendString: [self userInfoHTML]];
	
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
	[html appendString:@"<div class='artboard'><div id='tweet_area' class='tweet_area'>"];
	
	// User info
	[html appendString: [self tweetAreaHTML]];
	
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

- (void) showWebBrowserWithURLRequest:(NSURLRequest*)request {
	// Push a separate web browser for links
	WebBrowserViewController *vc = [[[WebBrowserViewController alloc] initWithURLRequest:request] autorelease];
	[self.navigationController pushViewController: vc animated: YES];
}	

#pragma mark WebView delegate methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *url = [request URL];
	
	if ([[url scheme] hasPrefix:@"http"]) {
		[self showWebBrowserWithURLRequest:request];
		return NO;
	}
	
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView {
	[appDelegate incrementNetworkActionCount];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
	[appDelegate decrementNetworkActionCount];
}

- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error {
	[appDelegate decrementNetworkActionCount];
	
	if ([error code] != -999) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString localizedStringWithFormat:@"Error %d", [error code]] message:[NSString localizedStringWithFormat:@"The page could not be loaded: \"%@\"", [error localizedDescription]] delegate:nil cancelButtonTitle:[NSString localizedStringWithFormat:@"OK"] otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
	screenNameButton.title = user.screenName;
	
	[self reloadWebView];
}

- (void)viewDidUnload {
    [super viewDidUnload];
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
