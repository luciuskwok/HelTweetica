//
//  InstapaperSettingsViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/12/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "InstapaperSettingsViewController.h"

#define kInstapaperUsernameKey @"instapaperUsername"
#define kInstapaperPasswordKey @"instapaperPassword"


@implementation InstapaperSettingsViewController
@synthesize usernameField, passwordField;


- (id) init {
	if (self = [super initWithNibName:@"InstapaperSettings" bundle:nil]) {
		self.modalPresentationStyle = UIModalPresentationFormSheet;
	}
	return self;
}

- (void)dealloc {
	[usernameField release];
	[passwordField release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Get Instapaper credentials
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *instapaperUsername = [defaults objectForKey: kInstapaperUsernameKey];
	NSString *instapaperPassword = [defaults objectForKey: kInstapaperPasswordKey];
	
	if (instapaperUsername != nil) 
		usernameField.text = instapaperUsername;
	else 
		usernameField.text = @"";
	
	if (instapaperPassword != nil) 
		passwordField.text = instapaperPassword;
	else
		passwordField.text = @"";
	
	// Title
	[self.navigationItem setTitle:@"Instapaper"];
	
	// Done button
	UIBarButtonItem *button = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(login:)] autorelease];
	self.navigationItem.rightBarButtonItem = button;
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.usernameField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.usernameField = nil;
	self.passwordField = nil;
}


- (IBAction) cancel: (id) sender {
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction) login: (id) sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *user = [self.usernameField text];
	NSString *pass = [self.passwordField text];
	
	if ([user length] == 0) {
		[defaults removeObjectForKey: kInstapaperUsernameKey];
	} else {
		[defaults setObject: user forKey: kInstapaperUsernameKey];
	}
	
	if ([pass length] == 0) {
		[defaults removeObjectForKey: kInstapaperPasswordKey];
	} else {
		[defaults setObject: pass forKey: kInstapaperPasswordKey];
	}

	// Close
	[self dismissModalViewControllerAnimated:YES];
	
	// Post notification
	[[NSNotificationCenter defaultCenter] postNotificationName:@"instapaperUsernameDidChange" object:self];
}

- (IBAction) openInSafari: (id) sender {
	NSURL *url = [NSURL URLWithString: [sender currentTitle]];
	[[UIApplication sharedApplication] openURL: url];
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
