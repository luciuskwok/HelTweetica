//
//  SearchWindowController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/24/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainWindowController.h"

@class Twitter, TwitterAccount;

@interface SearchWindowController : MainWindowController {
	IBOutlet NSButton *saveButton;
	NSString *query;
}
@property (assign) NSButton *saveButton;
@property (nonatomic, retain) NSString *query;


- (id)initWithTwitter:(Twitter*)aTwitter account:(TwitterAccount*)anAccount query:(NSString*)aQuery;
- (IBAction)saveSearch:(id)sender;

@end
