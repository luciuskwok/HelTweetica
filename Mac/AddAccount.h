//
//  AddAccount.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/22/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class Twitter;
@class TwitterAccount;
@protocol AddAccountDelegate;

@interface AddAccount : NSWindowController {
	IBOutlet NSTextField *usernameField;
	IBOutlet NSSecureTextField *passwordField;
	Twitter *twitter;
	id <AddAccountDelegate> delegate;
}
@property (assign) NSTextField *usernameField;
@property (assign) NSSecureTextField *passwordField;
@property (assign) id delegate;

- (id)initWithTwitter:(Twitter*)aTwitter;
- (void)askInWindow:(NSWindow *)window modalDelegate:(id)del didEndSelector:(SEL)sel;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

@end

@protocol AddAccountDelegate <NSObject>
- (void)didLoginToAccount:(TwitterAccount*)anAccount;
@end
