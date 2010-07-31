//
//  PostTweet.h
//  HelTweetica
//
//  Created by Lucius Kwok on 3/30/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "Twitter.h"
#import "LKShrinkURLAction.h"
@class HelTweeticaAppDelegate;


@protocol ComposeViewControllerDelegate;

@interface ComposeViewController : UIViewController <LKShrinkURLActionDelegate> {
	IBOutlet UITextView *messageField;
	IBOutlet UIBarButtonItem *sendButton;
	IBOutlet UIBarButtonItem *retweetStyleButton;
	IBOutlet UIBarButtonItem *geotagButton;
	IBOutlet UIBarButtonItem *shrinkURLsButton;
	IBOutlet UIBarButtonItem *charactersRemaining;
	IBOutlet UIToolbar *bottomToolbar;
	
	TwitterAccount *account;
	NSString *messageContent;
	NSNumber *inReplyTo;
	NSString *originalRetweetContent;
	BOOL newStyleRetweet;
	
	CLLocationManager *locationManager;
	NSMutableSet *actions;

	HelTweeticaAppDelegate *appDelegate;
	id delegate;
}
@property (nonatomic, retain) UITextView *messageField;
@property (nonatomic, retain) UIBarButtonItem *sendButton;
@property (nonatomic, retain) UIBarButtonItem *retweetStyleButton;
@property (nonatomic, retain) UIBarButtonItem *geotagButton;
@property (nonatomic, retain) UIBarButtonItem *shrinkURLsButton;
@property (nonatomic, retain) UIBarButtonItem *charactersRemaining;
@property (nonatomic, retain) UIToolbar *bottomToolbar;

@property (nonatomic, retain) TwitterAccount *account;
@property (nonatomic, retain) NSString *messageContent;
@property (nonatomic, retain) NSNumber *inReplyTo;
@property (nonatomic, retain) NSString *originalRetweetContent;
@property (nonatomic, assign) BOOL newStyleRetweet;

@property (nonatomic, retain) CLLocationManager *locationManager;

@property (assign) id <ComposeViewControllerDelegate> delegate;

- (id)initWithAccount:(TwitterAccount*)anAccount;
- (void) loadFromUserDefaults;
- (void) updateCharacterCountWithText:(NSString *)text;

- (IBAction)close:(id)sender;
- (IBAction)send:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)geotag:(id)sender;
- (IBAction)shrinkURLs:(id)sender;
- (IBAction)camera:(id)sender;

@end


@protocol ComposeViewControllerDelegate <NSObject>
- (void) compose:(ComposeViewController*)aCompose didSendMessage:(NSString*)text inReplyTo:(NSNumber*)inReplyTo location:(CLLocation *)location;
- (void) compose:(ComposeViewController*)aCompose didRetweetMessage:(NSNumber*)identifier;
@end

