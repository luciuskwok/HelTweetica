//
//  AddAccount
//  HelTweetica
//
//  Created by Lucius Kwok on 5/22/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AddAccount.h"
#import "Twitter.h"
#import "TwitterAccount.h"
#import "TwitterLoginAction.h"


@implementation AddAccount
@synthesize usernameField, passwordField, screenName, delegate;


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

- (void)windowDidLoad {
	if (screenName) {
		[usernameField setStringValue:screenName];
		[passwordField becomeFirstResponder];
	}
}

#pragma mark Login view controller delegate

- (void) loginWithScreenName:(NSString*)aScreenName password:(NSString*)password {
	// Create an account for this username if one doesn't already exist
	TwitterAccount *account = [twitter accountWithScreenName: aScreenName];
	if (account == nil) {
		account = [[[TwitterAccount alloc] init] autorelease];
		account.screenName = aScreenName;
		[twitter.accounts addObject: account];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"accountsDidChange" object:nil];
	}
	
	// Create and send the login action.
	TwitterLoginAction *action = [[[TwitterLoginAction alloc] initWithUsername:aScreenName password:password] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLogin:);
	
	// Set up Twitter action
	action.delegate = self;
	
	// Start the URL connection
	[action start];
}

- (void) didLogin:(TwitterLoginAction *)action {
	TwitterAccount *account = [twitter accountWithScreenName: action.username];
	if (action.token) {
		// Save the login information for the account.
		account.xAuthToken = action.token;
		account.xAuthSecret = action.secret;
		account.screenName = action.username; // To make sure the uppercase/lowercase letters are correct.
		account.identifier = action.identifier;
		
		// Tell delegate we're done
		if ([delegate respondsToSelector:@selector(didLoginToAccount:)])
			[delegate didLoginToAccount:account];
	} else {
		// Tell delegate that login failed
		if ([delegate respondsToSelector:@selector(loginFailedWithAccount:)])
			[delegate loginFailedWithAccount:account];
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
		[self endSheetWithReturnCode:1];
	} else if (user.length == 0) {
		[usernameField becomeFirstResponder];
	} else {
		[passwordField becomeFirstResponder];
	}
}

- (IBAction)cancel:(id)sender {
	[self endSheetWithReturnCode:0];
}


@end
