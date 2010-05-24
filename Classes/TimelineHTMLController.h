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
#import "LKWebView.h"

#import "Twitter.h"
#import "TwitterAccount.h"
#import "TwitterTimeline.h"
#import "TwitterMessage.h"
#import "TwitterList.h"


@class TwitterAction, TwitterLoadTimelineAction;
@protocol TimelineHTMLControllerDelegate;

@interface TimelineHTMLController : NSObject {
	LKWebView *webView;
	
	Twitter *twitter;
	TwitterAccount *account;
	TwitterTimeline *timeline;
	NSMutableArray *actions;

	NSString *tweetRowTemplate;
	NSString *tweetMentionRowTemplate;
	NSString *tweetGapRowTemplate;
	NSString *loadingHTML;

	NSString *customPageTitle;
	NSString *customTabName;
	
	NSNumber *defaultLoadCount;

	int maxTweetsShown;
	BOOL webViewHasValidHTML;
	BOOL isLoading;
	BOOL noInternetConnection;
	BOOL suppressNetworkErrorAlerts;
	
	NSTimer *refreshTimer;

	id <TimelineHTMLControllerDelegate> delegate;
}

@property (nonatomic, retain) LKWebView *webView;

@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) TwitterAccount *account;
@property (nonatomic, retain) TwitterTimeline *timeline;
@property (nonatomic, retain) NSMutableArray *actions;

@property (nonatomic, retain) NSString *customPageTitle;
@property (nonatomic, retain) NSString *customTabName;

@property (nonatomic, retain) NSNumber *defaultLoadCount;

@property (assign) BOOL webViewHasValidHTML;
@property (assign) BOOL isLoading;
@property (assign) BOOL noInternetConnection;
@property (assign) BOOL suppressNetworkErrorAlerts;

@property (assign) id delegate;

// Timeline selection
- (void)selectHomeTimeline;
- (void)selectMentionsTimeline;
- (void)selectDirectMessageTimeline;
- (void)selectFavoritesTimeline;
- (void)startLoadingCurrentTimeline;

// Loading
- (void)loadTimeline:(TwitterTimeline *)aTimeline;
- (void)loadOlderWithMaxIdentifier:(NSNumber*)maxIdentifier;
- (void)timeline:(TwitterTimeline *)aTimeline didLoadWithAction:(TwitterLoadTimelineAction *)action;
- (void)loadList:(TwitterList*)list;

// Twitter actions
- (void)startTwitterAction:(TwitterAction*)action;
- (void)handleTwitterStatusCode:(int)code;
- (void)twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error;
- (void)updateStatus:(NSString*)text inReplyTo:(NSNumber*)messageIdentifier;
- (void)fave: (NSNumber*) messageIdentifier;
- (void)retweet:(NSNumber*)messageIdentifier;

// Web view updating
- (void)loadWebView;
- (void)setLoadingSpinnerVisibility:(BOOL)isVisible;
- (void)rewriteTweetArea;

// Web actions
- (BOOL)handleWebAction:(NSString*)action;
- (NSNumber*)number64WithString:(NSString*)string;

// Refresh timer
- (void)scheduleRefreshTimer;
- (void)invalidateRefreshTimer;

// HTML
- (NSString *)webPageTemplate;
- (NSString *)currentAccountHTML;
- (NSString *)tabAreaHTML;
- (NSString *)tweetAreaHTML;
- (NSString *)tweetRowTemplateForRow:(int)row;
- (NSString *)tweetRowHTMLForRow:(int)row;
- (NSString *)tweetAreaFooterHTML;
- (NSString *)timeStringSinceNow: (NSDate*) date;
- (void)replaceBlock:(NSString*)blockName display:(BOOL)display inTemplate:(NSMutableString*)template;
- (NSString *)htmlFormattedString:(NSString*)string;

@end


@protocol TimelineHTMLControllerDelegate <NSObject> 
- (void)showAlertWithTitle:(NSString *)aTitle message:(NSString *)aMessage;
- (void)didSelectTimeline:(TwitterTimeline *)timeline;
@end
