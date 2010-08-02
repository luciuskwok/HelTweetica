//
//  WebBrowserViewController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 4/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@class HelTweeticaAppDelegate;
@protocol WebBrowserViewControllerDelegate;


@interface WebBrowserViewController : UIViewController <UIActionSheetDelegate, MFMailComposeViewControllerDelegate> {
	IBOutlet UIWebView *webView;
	IBOutlet UIBarButtonItem *backButton;
	IBOutlet UIBarButtonItem *forwardButton;
	IBOutlet UIBarButtonItem *stopButton;
	IBOutlet UIBarButtonItem *reloadButton;
	IBOutlet UILabel *titleLabel;

	UIActionSheet *currentActionSheet;
	NSURLRequest *request;
	
	BOOL addURLToInstapaperWhenUsernameChanges;

	HelTweeticaAppDelegate *appDelegate;
	id delegate;
}
@property (nonatomic, retain) UIWebView *webView;
@property (nonatomic, retain) UIBarButtonItem *backButton;
@property (nonatomic, retain) UIBarButtonItem *forwardButton;
@property (nonatomic, retain) UIBarButtonItem *stopButton;
@property (nonatomic, retain) UIBarButtonItem *reloadButton;
@property (nonatomic, retain) UILabel *titleLabel;

@property (nonatomic, retain) UIActionSheet *currentActionSheet;
@property (nonatomic, retain) NSURLRequest *request;

@property (nonatomic, assign) id <WebBrowserViewControllerDelegate> delegate;

- (id)initWithURLRequest:(NSURLRequest*)aRequest;

- (IBAction) done: (id) sender;
- (IBAction) instapaper: (id) sender;
- (IBAction) action: (id) sender;

@end

@protocol WebBrowserViewControllerDelegate
- (void)browser:(WebBrowserViewController *)browser didFinishWithURLToTweet:(NSURL *)url;
@end
