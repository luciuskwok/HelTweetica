//
//  TimelineHTMLController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/22/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterTimeline.h"
#import "LKWebView.h"


@class Twitter, TwitterAccount, TwitterList;
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

// Timeline selection
- (void) selectHomeTimeline;
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
- (void)handleWebAction:(NSString*)action;
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
@end