//
//  Compose.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/25/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>
#import "LKShrinkURLAction.h"
#import "LKUploadPictureAction.h"
#import "TwitterAccount.h"


@protocol ComposeDelegate;

@interface Compose : NSWindowController <LKShrinkURLActionDelegate, LKUploadPictureActionDelegate> {
	IBOutlet NSTextField *textField;
	IBOutlet NSTextField *charactersRemaining;
	IBOutlet NSTextField *tooLongLabel;
	IBOutlet NSSegmentedControl *retweetStyleControl;
	IBOutlet NSButton *shrinkURLButton;
	IBOutlet NSButton *locationButton;
	IBOutlet NSButton *tweetButton;
	IBOutlet NSButton *pictureButton;
	IBOutlet NSProgressIndicator *activityIndicator;
	
	NSString *senderScreenName;
	NSString *messageContent;
	NSNumber *inReplyTo;
	NSString *originalRetweetContent;
	BOOL newStyleRetweet;
	
	CLLocationManager *locationManager;
	NSMutableSet *actions;
	
	id delegate;
}

@property (assign) NSTextField *textField;
@property (assign) NSTextField *charactersRemaining;
@property (assign) NSTextField *tooLongLabel;
@property (assign) NSSegmentedControl *retweetStyleControl;
@property (assign) NSButton *shrinkURLButton;
@property (assign) NSButton *locationButton;
@property (assign) NSButton *tweetButton;
@property (assign) NSButton *pictureButton;
@property (assign) NSProgressIndicator *activityIndicator;

@property (nonatomic, retain) NSString *senderScreenName;
@property (nonatomic, retain) NSString *messageContent;
@property (nonatomic, retain) NSNumber *inReplyTo;
@property (nonatomic, retain) NSString *originalRetweetContent;
@property (assign) BOOL newStyleRetweet;

@property (assign) id <ComposeDelegate> delegate;

// UI updating
- (void)updateCharacterCount;

// Sheet
- (void) askInWindow:(NSWindow *)aWindow modalDelegate:(id)del didEndSelector:(SEL)sel;

// Actions
- (IBAction)selectRetweetStyle:(id)sender;
- (IBAction)location:(id)sender;
- (IBAction)shrinkURLs:(id)sender;
- (IBAction)addPicture:(id)sender;
- (IBAction)tweet:(id)sender;
- (IBAction)close:(id)sender;

@end

@protocol ComposeDelegate
- (void) compose:(Compose*)aCompose didSendMessage:(NSString*)text inReplyTo:(NSNumber*)inReplyTo location:(CLLocation *)location;
- (void) compose:(Compose*)aCompose didRetweetMessage:(NSNumber*)identifier;
@end
