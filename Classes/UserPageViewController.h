//
//  UserPageViewController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
@class LKWebView;
@class Twitter;
@class TwitterUser;


@interface UserPageViewController : UIViewController {
	IBOutlet LKWebView *webView;
	IBOutlet UIBarButtonItem *followButton;
	IBOutlet UIBarButtonItem *directMessageButton;

	UIPopoverController *currentPopover;

	Twitter *twitter;
	TwitterUser *user;
}
@property (nonatomic, retain) LKWebView *webView;
@property (nonatomic, retain) UIBarButtonItem *followButton;
@property (nonatomic, retain) UIBarButtonItem *directMessageButton;

@property (nonatomic, retain) UIPopoverController *currentPopover;

@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) TwitterUser *user;

- (id)initWithTwitter:(Twitter*)aTwitter user:(TwitterUser*)aUser;

- (IBAction)close:(id)sender;
- (IBAction)follow:(id)sender;
- (IBAction)directMessage:(id)sender;

@end
