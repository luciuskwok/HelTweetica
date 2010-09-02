//
//  TwitterComposer.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 8/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "TwitterAction.h"
#import "LKShrinkURLAction.h"
#import "LKUploadPictureAction.h"
@class Twitter, TwitterAccount,TwitterSendDirectMessageAction;
@protocol TwitterComposerDelegate;


@interface TwitterComposer : NSObject <TwitterActionDelegate, LKShrinkURLActionDelegate, LKUploadPictureActionDelegate> {
	Twitter *twitter;
	TwitterAccount *account;
	CLLocationManager *locationManager;
	NSMutableSet *actions;
	
	id delegate;
	
}
@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) TwitterAccount *account;
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) NSMutableSet *actions;
@property (assign) id <TwitterComposerDelegate> delegate;

- (id)initWithTwitter:(Twitter *)aTwitter account:(TwitterAccount *)anAccount;

// Network actions
- (NSUInteger)numberOfNetworkActions;
- (void)cancelActions;

// Tweet and Retweet
- (void)retweetMessageWithIdentifier:(NSNumber *)messageIdentifier;
- (void)updateStatus:(NSString *)text inReplyTo:(NSNumber *)reply location:(CLLocation *)location;
- (void)sendDirectMessage:(NSString *)text to:(NSString*)screenName;

// Actions
- (void)shrinkURLsInString:(NSString *)string;
- (void)uploadPicture:(NSData *)picture withFileExtension:(NSString *)ext;
- (void)didSendDirectMessage:(TwitterSendDirectMessageAction*)action;

@end


// Delegate
@protocol TwitterComposerDelegate
- (void)composerDidStartNetworkAction:(TwitterComposer *)aComposer;
- (void)composerDidFinishNetworkAction:(TwitterComposer *)aComposer;
- (void)composerDidFinishSendingStatusUpdate:(TwitterComposer *)aComposer;
- (void)composerDidFinishSendingDirectMessage:(TwitterComposer *)aComposer;
- (void)composerDidFailSendingDirectMessage:(TwitterComposer *)aComposer error:(NSError*)error;
- (void)composer:(TwitterComposer *)aComposer didShrinkLongURL:(NSString *)longURL toShortURL:(NSString *)shortURL;
- (void)composer:(TwitterComposer *)aComposer didUploadPictureWithURL:(NSString *)url;
- (void)composer:(TwitterComposer *)aComposer didFailWithError:(NSError *)error;

@end
