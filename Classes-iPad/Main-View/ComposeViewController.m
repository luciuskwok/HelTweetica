//
//  PostTweet.m
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


#import "ComposeViewController.h"

enum { kTwitterCharacterMax = 140 };


@implementation ComposeViewController
@synthesize messageField, sendButton, retweetStyleButton, charactersRemaining, bottomToolbar;
@synthesize account, messageContent, inReplyTo, originalRetweetContent, newStyleRetweet;
@synthesize delegate;


- (id)initWithAccount:(TwitterAccount*)anAccount {
	if (self = [super initWithNibName:@"Compose" bundle:nil]) {
		// Twitter
		self.account = anAccount;
		
		// Title
		if (account.screenName == nil) {
			self.navigationItem.title = @"—";
		} else {
			self.navigationItem.title = account.screenName;
		}
		
		// Clear button
		NSString *clearTitle = NSLocalizedString (@"Clear", @"");
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:clearTitle style:UIBarButtonItemStyleBordered target:self action:@selector(clear:)] autorelease];
		
		// Close button
		if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
			NSString *closeTitle = NSLocalizedString (@"Close", @"");
			self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:closeTitle style:UIBarButtonItemStylePlain target:self action:@selector(close:)] autorelease];
		}
		
		// Content size for popover
		if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
			[self setContentSizeForViewInPopover: CGSizeMake(480, 320)];
		}
		
	}
	return self;
}

- (void)dealloc {
	[messageField release];
	[sendButton release];
	[retweetStyleButton release];
	[charactersRemaining release];
	[bottomToolbar release];
	
	[account release];
	[messageContent release];
	[inReplyTo release];
	[originalRetweetContent release];
	
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) loadFromUserDefaults {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	self.messageContent = [defaults objectForKey:@"messageContent"];
	self.inReplyTo = [defaults objectForKey:@"inReplyTo"];
	self.originalRetweetContent = [defaults objectForKey:@"originalRetweetContent"];
	self.newStyleRetweet = [defaults boolForKey:@"newStyleRetweet"];
}

- (NSString*) retweetStyleButtonTitle {
	return newStyleRetweet ? NSLocalizedString (@"RT style: New", "button") : NSLocalizedString (@"RT style: Old", "button");
}

- (void) setNewStyleRetweet:(BOOL)x {
	newStyleRetweet = x;
	self.retweetStyleButton.title = [self retweetStyleButtonTitle];
	if (newStyleRetweet && originalRetweetContent) {
		// Reinstate original retweet message and disable editing
		self.messageField.text = originalRetweetContent;
		self.messageField.editable = NO;
	} else {
		// Allow editing
		self.messageField.editable = YES;
		[self updateCharacterCountWithText: messageField.text];
		[self.messageField becomeFirstResponder];
	}
}

- (void) viewDidLoad {
	[super viewDidLoad];
	
	// Message
	if (messageContent != nil) {
		messageField.text = messageContent;
		[self updateCharacterCountWithText:messageContent];
	}
	
	// Retweet style
	if (originalRetweetContent != nil) {
		NSString *title = [self retweetStyleButtonTitle];
		self.retweetStyleButton = [[[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleBordered target:self action:@selector(toggleRetweetStyle:)] autorelease];
		NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray: bottomToolbar.items];
		[toolbarItems insertObject:retweetStyleButton atIndex:1];
		bottomToolbar.items = toolbarItems;
		[self setNewStyleRetweet:newStyleRetweet];
	}
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.messageField = nil;
	self.charactersRemaining = nil;
	self.retweetStyleButton = nil;
}

- (void) updateCharacterCountWithText:(NSString *)text {
	if (originalRetweetContent && newStyleRetweet) { // New-style RT doesn't require counting chars
		charactersRemaining.title = @"";
		sendButton.enabled = YES;
	} else {
		// Convert the status to Unicode Normalized Form C to conform to Twitter's character counting requirement. See http://apiwiki.twitter.com/Counting-Characters .
		NSString *normalizationFormC = [text precomposedStringWithCanonicalMapping];
		int remaining = kTwitterCharacterMax - [normalizationFormC length];
		if (remaining < 0) {
			charactersRemaining.title = [NSString stringWithFormat:@"Too long! %d", remaining];
		} else {
			charactersRemaining.title = [NSString stringWithFormat:@"%d", remaining];
		}
		// Verify message length and account for Send button
		sendButton.enabled = (([normalizationFormC length] != 0) && (remaining >= 0) && (account != nil));
	}
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.messageField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	// Save message to user defaults for later
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [messageField text] forKey:@"messageContent"];
	[defaults setObject: inReplyTo forKey:@"inReplyTo"];
	[defaults setObject: originalRetweetContent forKey:@"originalRetweetContent"];
	[defaults setBool: newStyleRetweet forKey:@"newStyleRetweet"];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (IBAction) close: (id) sender {
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction) send: (id) sender {
	if (originalRetweetContent && newStyleRetweet) {
		[delegate compose:self didRetweetMessage:inReplyTo];
	} else { // Plain old status update
		// Check length
		NSString *text = messageField.text;
		// Convert the status to Unicode Normalized Form C to conform to Twitter's character counting requirement. See http://apiwiki.twitter.com/Counting-Characters .
		NSString *normalizedText = [text precomposedStringWithCanonicalMapping];
		if ((normalizedText.length == 0) || (normalizedText.length > kTwitterCharacterMax)) {
			return;
		}
		
		// Location
		CLLocation *location = nil;
		
		[delegate compose:self didSendMessage:normalizedText inReplyTo:inReplyTo location:location];
	}
	
	self.messageContent = nil;
	self.inReplyTo = nil;
	[self close: nil];
}

- (IBAction) clear: (id) sender {
	messageField.text = @"";
	originalRetweetContent = nil;
	[self updateCharacterCountWithText:@""];
	[self setNewStyleRetweet: newStyleRetweet];
	
	// Remove RT-Style button
	if (retweetStyleButton) {
		NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray: bottomToolbar.items];
		[toolbarItems removeObject:retweetStyleButton];
		bottomToolbar.items = toolbarItems;
		self.retweetStyleButton = nil;
	}
	
}

- (IBAction) toggleRetweetStyle: (id) sender {
	self.newStyleRetweet = !newStyleRetweet;
	[self updateCharacterCountWithText:messageField.text];
}

#pragma mark Text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
	[self updateCharacterCountWithText: textView.text];
}

@end
