    //
//  TimelineViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/3/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TimelineViewController.h"
#import "LKWebView.h"
#import "HelTweeticaAppDelegate.h"


@implementation TimelineViewController
@synthesize webView, twitter, actions, defaultCount;
@synthesize currentPopover, currentActionSheet, currentAlert;


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
	self.webView = nil;
}

- (void)dealloc {
	[webView release];
	[twitter release];
	[actions release];
	[defaultCount release];
    [super dealloc];
}

- (void) awakeFromNib {
	// Use Twitter instance from app delegate
	HelTweeticaAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	self.twitter = appDelegate.twitter;
	
	// String to pass in the count, per_page, and rpp parameters.
	self.defaultCount = @"100";
	
	// List of currently active network connections
	self.actions = [NSMutableArray array];
}

@end
