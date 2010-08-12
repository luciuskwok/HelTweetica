//
//  TimelineHTMLController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/22/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "LKWebView.h"

#import "Twitter.h"
#import "TwitterAccount.h"
#import "TwitterTimeline.h"
#import "TwitterDirectMessageTimeline.h"
#import "TwitterStatusUpdate.h"
#import "TwitterList.h"
#import "TwitterAction.h"

@protocol TimelineHTMLControllerDelegate;



@interface TimelineHTMLController : NSObject {
	LKWebView *webView;
	
	Twitter *twitter;
	TwitterAccount *account;
	TwitterTimeline *timeline;
	NSArray *messages;

	NSString *directMessageRowTemplate;
	NSString *directMessageRowSectionOpenTemplate;
	NSString *directMessageRowSectionCloseHTML;
	NSString *tweetRowTemplate;
	NSString *tweetGapRowTemplate;
	NSString *loadingHTML;

	NSString *customPageTitle;
	NSString *customTabName;
	
	int maxTweetsShown;
	BOOL webViewHasValidHTML;
	BOOL isLoading;
	BOOL noInternetConnection;
	BOOL suppressNetworkErrorAlerts;
	
	NSTimer *rewriteHTMLTimer;
	BOOL useRewriteHTMLTimer;
	
	id delegate;
}

@property (nonatomic, retain) LKWebView *webView;

@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) TwitterAccount *account;
@property (nonatomic, retain) TwitterTimeline *timeline;
@property (nonatomic, retain) NSArray *messages;

@property (nonatomic, retain) NSString *customPageTitle;
@property (nonatomic, retain) NSString *customTabName;

@property (assign) int maxTweetsShown;
@property (assign) BOOL webViewHasValidHTML;
@property (assign) BOOL isLoading;
@property (assign) BOOL noInternetConnection;
@property (assign) BOOL suppressNetworkErrorAlerts;

@property (assign) BOOL useRewriteHTMLTimer;

@property (assign) id <TimelineHTMLControllerDelegate> delegate;

// Timeline selection
- (void)selectHomeTimeline;
- (void)selectMentionsTimeline;
- (void)selectDirectMessageTimeline;
- (void)selectFavoritesTimeline;

// Twitter status line
- (void)showTwitterStatusWithString:(NSString *)string;
- (void)hideTwitterStatus;

// Loading
- (void)refresh;
- (void)loadTimeline:(TwitterTimeline *)aTimeline;
- (void)loadOlderWithMaxIdentifier:(NSNumber*)maxIdentifier;
- (void)loadList:(TwitterList*)list;
- (void)timelineDidFinishLoading:(NSNotification *)notification;

// Twitter actions
- (void)fave: (NSNumber*) messageIdentifier;
- (void)deleteStatusUpdate:(NSNumber*)messageIdentifier;

// Web view updating
- (void)loadWebView;
- (void)rewriteTweetArea;
- (void)scheduleRewriteHTMLTimer;

// Web actions
- (BOOL)handleWebAction:(NSString*)action;
- (NSNumber*)number64WithString:(NSString*)string;

// HTML
- (NSString *)loadHTMLTemplate:(NSString *)templateName;
- (NSString *)styleForStatusUpdate:(TwitterStatusUpdate *)statusUpdate rowIndex:(int)rowIndex;
- (NSString *)webPageTemplate;
- (NSString *)currentAccountHTML;
- (NSString *)tabAreaHTML;
- (NSString *)tweetAreaHTML;
- (NSString *)tweetAreaFooterHTML;
- (void)replaceBlock:(NSString*)blockName display:(BOOL)display inTemplate:(NSMutableString*)template;

@end


@protocol TimelineHTMLControllerDelegate <NSObject> 
@required
- (void)showAlertWithTitle:(NSString *)aTitle message:(NSString *)aMessage;
@optional
- (void)didSelectTimeline:(TwitterTimeline *)timeline;
@end
