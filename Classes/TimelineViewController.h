//
//  TimelineViewController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/3/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


// Constants
#define kMaxNumberOfMessagesInATimeline 2000
// When reloading a timeline, newly downloaded messages are merged with existing ones, sorted by identifier, and the oldest ones past this limit are trimmed off.
#define kMaxMessageStaleness (2 * 60 * 60) 
// When reloading a timeline, when the newest message in the app is older than this, the app reloads the entire timeline instead of requesting only status updates newer than the newest in the app. This is set to 2 hours. The value is in seconds.


#import <UIKit/UIKit.h>
#import "LKWebView.h"
#import "Twitter.h"
#import "ListsViewController.h"
#import "SearchViewController.h"
#import "ComposeViewController.h"
#import "GoToUserViewController.h"

@class TwitterAction;
@class TwitterTimeline;
@class TwitterLoadTimelineAction;


@interface TimelineViewController : UIViewController <UIPopoverControllerDelegate, ListsViewControllerDelegate, SearchViewControllerDelegate, ComposeViewControllerDelegate, GoToUserViewControllerDelegate> {
	IBOutlet LKWebView *webView;
	IBOutlet UIBarButtonItem *composeButton;

	HelTweeticaAppDelegate *appDelegate;

	Twitter *twitter;
	NSMutableArray *actions;
	NSString *defaultLoadCount;
	int maxTweetsShown;

	NSTimer *refreshTimer;
	BOOL networkIsReachable;
	BOOL webViewHasValidHTML;
	BOOL suppressNetworkErrorAlerts;
	BOOL noOlderMessages;

	TwitterAccount *currentAccount;
	TwitterTimeline *currentTimeline;
	NSString *customPageTitle;
	NSString *customTabName;
	
	UIPopoverController *currentPopover;
	UIActionSheet *currentActionSheet;
	UIAlertView *currentAlert;
	
	NSString *tweetRowTemplate;
	NSString *tweetMentionRowTemplate;
	NSString *tweetGapRowTemplate;
	NSString *loadingHTML;
}
@property (nonatomic, retain) LKWebView *webView;
@property (nonatomic, retain) UIBarButtonItem *composeButton;

@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) NSMutableArray *actions;
@property (nonatomic, retain) NSString *defaultLoadCount;

@property (nonatomic, retain) TwitterAccount *currentAccount;
@property (nonatomic, retain) TwitterTimeline *currentTimeline;
@property (nonatomic, retain) NSString *customPageTitle;
@property (nonatomic, retain) NSString *customTabName;

@property (nonatomic, retain) UIPopoverController *currentPopover;
@property (nonatomic, retain) UIActionSheet *currentActionSheet;
@property (nonatomic, retain) UIAlertView *currentAlert;

// IBActions
- (IBAction) close:(id)sender;
- (IBAction) search: (id) sender;
- (IBAction) goToUser:(id)sender;
- (IBAction) reloadData: (id) sender;
- (IBAction) compose: (id) sender;

// Twitter actions
- (void)startTwitterAction:(TwitterAction*)action;
- (void)handleTwitterStatusCode:(int)code;
- (void)twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error;

- (void)reloadCurrentTimeline;
- (void)didReloadCurrentTimeline:(TwitterLoadTimelineAction *)action;
- (void)reloadRetweetsSince:(NSNumber*)sinceIdentifier toMax:(NSNumber*)maxIdentifier;
- (void)startLoadingCurrentTimeline;
- (void)updateStatus:(NSString*)text inReplyTo:(NSNumber*)messageIdentifier;
- (void)fave: (NSNumber*) messageIdentifier;
- (void)retweet:(NSNumber*)messageIdentifier;
- (void)replyToMessage: (NSNumber*)identifier;
- (void)directMessageWithTweet:(NSNumber*)identifier;

// Popovers
- (BOOL)closeAllPopovers;
- (UIPopoverController*) presentPopoverFromItem:(UIBarButtonItem*)item viewController:(UIViewController*)vc;
- (void) presentContent: (UIViewController*) contentViewController inNavControllerInPopoverFromItem: (UIBarButtonItem*) item;

// Pushable view controllers
- (void) showUserPage:(NSString*)screenName;
- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier;
- (void) showWebBrowserWithURLRequest:(NSURLRequest*)request;

// Web view updating
- (void) reloadWebView;
- (void) setLoadingSpinnerVisibility: (BOOL) isVisible;
- (void) rewriteTweetArea;
- (NSString *)webPageTemplate; // Subclasses should override this to provide their own HTML template.
- (NSString *)tweetAreaHTML;
- (NSString *)tweetRowTemplateForRow:(int)row;
- (NSString *)tweetRowHTMLForRow:(int)row;
- (NSString *)tweetAreaFooterHTML;
- (NSString *)timeStringSinceNow: (NSDate*) date;
- (void)replaceBlock:(NSString*)blockName display:(BOOL)display inTemplate:(NSMutableString*)template;
- (NSString *)htmlFormattedString:(NSString*)string;


// Web view delegate methods
- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
- (void)webViewDidStartLoad:(UIWebView *)aWebView;
- (void)webViewDidFinishLoad:(UIWebView *)aWebView;
- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error;

// Alert view
- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage;

@end
