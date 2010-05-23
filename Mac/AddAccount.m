//
//  AddAccount
//  HelTweetica
//
//  Created by Lucius Kwok on 5/22/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "AddAccount.h"
#import "Twitter.h"
#import "TwitterAccount.h"
#import "TwitterLoginAction.h"


@implementation AddAccount
@synthesize usernameField, passwordField, delegate;


- (id)initWithTwitter:(Twitter*)aTwitter {
	if (self = [self initWithWindowNibName:@"AddAccount"]) {
		twitter = [aTwitter retain];
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	[super dealloc];
}

#pragma mark Login view controller delegate

- (void) loginWithScreenName:(NSString*)screenName password:(NSString*)password {
	// Create an account for this username if one doesn't already exist
	TwitterAccount *account = [twitter accountWithScreenName: screenName];
	if (account == nil) {
		account = [[[TwitterAccount alloc] init] autorelease];
		account.screenName = screenName;
		[twitter.accounts addObject: account];
	}
	
	// Create and send the login action.
	TwitterLoginAction *action = [[[TwitterLoginAction alloc] initWithUsername:screenName password:password] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLogin:);
	
	// Set up Twitter action
	action.delegate = self;
	
	// Start the URL connection
	[action start];
}

- (void) didLogin:(TwitterLoginAction *)action {
	if (action.token) {
		// Save the login information for the account.
		TwitterAccount *account = [twitter accountWithScreenName: action.username];
		[account setXAuthToken: action.token];
		[account setXAuthSecret: action.secret];
		[account setScreenName: action.username]; // To make sure the uppercase/lowercase letters are correct.
		
		// Tell delegate we're done
		if ([delegate respondsToSelector:@selector(didLoginToAccount:)])
			[delegate didLoginToAccount:account];
	} else {
		// TODO: Login was not successful, so report the error.
		//NSString *title = NSLocalizedString (@"Login failed: Username or password was incorrect.", @"status");
	}
}

#pragma mark Sheet

- (void) askInWindow:(NSWindow *)aWindow modalDelegate:(id)del didEndSelector:(SEL)sel {
	[NSApp beginSheet: [self window] modalForWindow:aWindow modalDelegate:del didEndSelector:sel contextInfo:self];
}

- (void) endSheetWithReturnCode:(int)code {
	// End editing of current text field so it will update
	NSWindow *aWindow = [self window];
	[aWindow makeFirstResponder:aWindow];
	
	// End and close sheet
	[NSApp endSheet: aWindow returnCode:code];
	[aWindow orderOut: self];
}

- (IBAction)ok:(id)sender {
	NSString *user = [self.usernameField stringValue];
	NSString *pass = [self.passwordField stringValue];
	
	if (user.length > 0 && pass.length > 0) {
		[self loginWithScreenName:user password:pass];
	}
	
	[self endSheetWithReturnCode:1];
}

- (IBAction)cancel:(id)sender {
	[self endSheetWithReturnCode:0];
}


@end
