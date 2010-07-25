//
//  Login.m
//  HelTweetica
//
//  Created by Lucius Kwok on 3/30/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "LoginViewController.h"
#import "TwitterAccount.h"



@implementation LoginViewController
@synthesize usernameField, passwordField, screenName, delegate;

- (id)initWithTwitter:(Twitter*)aTwitter {
	if (self = [super initWithNibName:@"Login" bundle:nil]) {
		twitter = [aTwitter retain];
		if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
			[self setContentSizeForViewInPopover: CGSizeMake(320, 44 * 3)];
		}
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	[usernameField release];
	[passwordField release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.usernameField = nil;
	self.passwordField = nil;
}

- (void) viewDidLoad {
	[super viewDidLoad];
	if (screenName != nil)
		usernameField.text = screenName;

	// Title
	[self.navigationItem setTitle:@"Twitter Login"];
	
	// Add button
	NSString *title = NSLocalizedString (@"Send", @"");
	UIBarButtonItem *button = [[[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleDone target:self action:@selector(login:)] autorelease];
	self.navigationItem.rightBarButtonItem = button;
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.usernameField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (IBAction) cancel: (id) sender {
	[self.navigationController popViewControllerAnimated: YES];
}

- (IBAction) login: (id) sender {
	NSString *user = [self.usernameField text];
	NSString *pass = [self.passwordField text];
	
	if (([user length] == 0) || ([pass length] == 0)) return;
	
	// Call delegate with login info
	if ([delegate respondsToSelector:@selector(loginWithScreenName:password:)])
		[delegate loginWithScreenName:user password:pass];
	
	[self.navigationController popViewControllerAnimated: YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField == usernameField) {
		[self.passwordField becomeFirstResponder];
	} else {
		[self login:nil];
	}
	return NO;
}

@end
