//
//  UserWindowController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/24/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainWindowController.h"
#import "UserPageHTMLController.h"

@class Twitter, TwitterAccount, TwitterUser, HelTweeticaAppDelegate;


@interface UserWindowController : MainWindowController {
	IBOutlet NSButton *followButton;
}

@property (assign) NSButton *followButton;

- (id)initWithTwitter:(Twitter*)aTwitter account:(TwitterAccount*)account user:(TwitterUser*)aUser;


@end
