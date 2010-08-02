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




#import <UIKit/UIKit.h>
#import "LKWebView.h"
#import "Twitter.h"
#import "ListsViewController.h"
#import "SearchViewController.h"
#import "ComposeViewController.h"
#import "GoToUserViewController.h"
#import "TimelineHTMLController.h"
#import "WebBrowserViewController.h"


@class TwitterAction, TwitterLoadTimelineAction, TwitterTimeline;


@interface TimelineViewController : UIViewController <UIPopoverControllerDelegate, ListsViewControllerDelegate, SearchViewControllerDelegate, ComposeViewControllerDelegate, GoToUserViewControllerDelegate, TimelineHTMLControllerDelegate, WebBrowserViewControllerDelegate> {
	IBOutlet LKWebView *webView;
	IBOutlet UIBarButtonItem *composeButton;

	HelTweeticaAppDelegate *appDelegate;

	Twitter *twitter;
	TimelineHTMLController *timelineHTMLController;

	BOOL webViewHasFinishedLoading;
	
	UIPopoverController *currentPopover;
	UIActionSheet *currentActionSheet;
	UIAlertView *currentAlert;
}
@property (nonatomic, retain) LKWebView *webView;
@property (nonatomic, retain) UIBarButtonItem *composeButton;

@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) TimelineHTMLController *timelineHTMLController;

@property (nonatomic, retain) UIPopoverController *currentPopover;
@property (nonatomic, retain) UIActionSheet *currentActionSheet;
@property (nonatomic, retain) UIAlertView *currentAlert;

// IBActions
- (IBAction) close:(id)sender;
- (IBAction) search: (id) sender;
- (IBAction) goToUser:(id)sender;
- (IBAction) reloadData: (id) sender;

// Compose
- (IBAction) compose: (id) sender;
- (void)retweet:(NSNumber*)identifier;
- (void)replyToMessage: (NSNumber*)identifier;

// Popovers
- (BOOL)closeAllPopovers;
- (UIPopoverController*) presentViewController:(UIViewController*)vc inPopoverFromItem:(UIBarButtonItem*)item;
- (void) presentViewController:(UIViewController*)viewController inNavControllerInPopoverFromItem: (UIBarButtonItem*) item;

// Pushable view controllers
- (void) showUserPage:(NSString*)screenName;
- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier;
- (void) showWebBrowserWithURLRequest:(NSURLRequest*)request;

// Web view delegate methods
- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
- (void)webViewDidStartLoad:(UIWebView *)aWebView;
- (void)webViewDidFinishLoad:(UIWebView *)aWebView;
- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error;

// Alert view
- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage;

@end
