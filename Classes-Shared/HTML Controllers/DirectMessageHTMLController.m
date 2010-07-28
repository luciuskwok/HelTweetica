//
//  DirectMessageHTMLController.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/27/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "DirectMessageHTMLController.h"


@implementation DirectMessageHTMLController
@synthesize webView, messages;

- (void)dealloc {
	[webView release];
	[messages release];
	[super dealloc];
}

@end
