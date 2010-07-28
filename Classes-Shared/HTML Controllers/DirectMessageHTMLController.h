//
//  DirectMessageHTMLController.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/27/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LKWebView.h"
#import "Twitter.h"
#import "TwitterAccount.h"

@interface DirectMessageHTMLController : NSObject {
	LKWebView *webView;
	NSMutableArray *messages;
}

@property (nonatomic, retain) LKWebView *webView;
@property (nonatomic, retain) NSMutableArray *messages;

@end
