//
//  TimelineViewController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/3/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LKWebView.h"
#import "Twitter.h"


@interface TimelineViewController : UIViewController {
	IBOutlet LKWebView *webView;

	Twitter *twitter;
	NSMutableArray *actions;
	NSString *defaultCount;

	UIPopoverController *currentPopover;
	UIActionSheet *currentActionSheet;
	UIAlertView *currentAlert;
	
}
@property (nonatomic, retain) LKWebView *webView;

@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) NSMutableArray *actions;
@property (nonatomic, retain) NSString *defaultCount;

@property (nonatomic, retain) UIPopoverController *currentPopover;
@property (nonatomic, retain) UIActionSheet *currentActionSheet;
@property (nonatomic, retain) UIAlertView *currentAlert;

@end
