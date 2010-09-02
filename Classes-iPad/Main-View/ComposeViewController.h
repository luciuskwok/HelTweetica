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
#import "TwitterComposer.h"
#import "AccountsViewController.h"
#import "GoToUserViewController.h"
@class HelTweeticaAppDelegate, TwitterAccount;


@protocol ComposeViewControllerDelegate;

@interface ComposeViewController : UIViewController 
	<TwitterComposerDelegate, AccountsViewControllerDelegate, GoToUserViewControllerDelegate, 
	UINavigationControllerDelegate, UIImagePickerControllerDelegate, 
	UIPopoverControllerDelegate, UIActionSheetDelegate> 
{
	IBOutlet UITextView *messageField;
	
	IBOutlet UIToolbar *topToolbar;
	IBOutlet UIBarButtonItem *accountButton;
	IBOutlet UIBarButtonItem *retweetStyleButton;
	IBOutlet UIBarButtonItem *userButton;
	IBOutlet UIBarButtonItem *photosButton;
	IBOutlet UIBarButtonItem *sendButton;
	
	IBOutlet UIToolbar *inputToolbar;
	IBOutlet UIBarButtonItem *geotagButton;
	IBOutlet UIBarButtonItem *charactersRemaining;
	
	TwitterComposer *composer;
	UIPopoverController *currentPopover;
	UIActionSheet *currentActionSheet;
	HelTweeticaAppDelegate *appDelegate;
	id delegate;
	NSString *directMessageToScreename;
}
@property (nonatomic, retain) UITextView *messageField;

@property (nonatomic, retain) UIToolbar *topToolbar;
@property (nonatomic, retain) UIBarButtonItem *accountButton;
@property (nonatomic, retain) UIBarButtonItem *retweetStyleButton;
@property (nonatomic, retain) UIBarButtonItem *userButton;
@property (nonatomic, retain) UIBarButtonItem *photosButton;
@property (nonatomic, retain) UIBarButtonItem *sendButton;

@property (nonatomic, retain) UIToolbar *inputToolbar;
@property (nonatomic, retain) UIBarButtonItem *geotagButton;
@property (nonatomic, retain) UIBarButtonItem *charactersRemaining;

@property (nonatomic, retain) UIPopoverController *currentPopover;
@property (nonatomic, retain) UIActionSheet *currentActionSheet;
@property (assign) id <ComposeViewControllerDelegate> delegate;
@property (nonatomic, copy) NSString *directMessageToScreename;

- (id)initWithAccount:(TwitterAccount*)anAccount;
- (id)initDirectMessageWithAccount:(TwitterAccount*)anAccount to:(NSString*)screenName;
- (void)updateCharacterCountWithText:(NSString *)text;

- (IBAction)send:(id)sender;
- (IBAction)close:(id)sender;
- (IBAction)chooseAccount:(id)sender;
- (IBAction)toggleRetweetStyle:(id)sender;

- (IBAction)toggleGeotag:(id)sender;
- (IBAction)shrinkURLs:(id)sender;
- (IBAction)addPicture:(id)sender;
- (IBAction)addUser:(id)sender;
- (IBAction)clear:(id)sender;

@end


@protocol ComposeViewControllerDelegate <NSObject>
- (void)composeDidFinish:(ComposeViewController*)aCompose;
@end

