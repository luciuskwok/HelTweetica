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

#define kTwitterCharacterMax 140


@interface ComposeViewController (PrivateMethods)
- (void) updateCharacterCountWithText:(NSString *)text;
@end


@implementation ComposeViewController
@synthesize messageField, charactersRemaining, messageContent, inReplyTo, popover;

- (id)initWithTwitter:(Twitter*)aTwitter {
	if (self = [super initWithNibName:@"Compose" bundle:nil]) {
		// Twitter
		twitter = [aTwitter retain];
		
		// Title
		if (twitter.currentAccount.screenName == nil) {
			self.navigationItem.title = @"—";
		} else {
			self.navigationItem.title = twitter.currentAccount.screenName;
		}
		
		// Send button
		NSString *sendTitle = NSLocalizedString (@"Send", @"");
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:sendTitle style:UIBarButtonSystemItemDone target:self action:@selector(send:)] autorelease];
		
		// Close button
		if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
			NSString *closeTitle = NSLocalizedString (@"Close", @"");
			self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:closeTitle style:UIBarButtonItemStylePlain target:self action:@selector(close:)] autorelease];
		}
		
		// Content size for popover
		if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
			[self setContentSizeForViewInPopover: CGSizeMake(320, 200)];
		}
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		self.messageContent = [defaults objectForKey:@"messageContent"];
		self.inReplyTo = [defaults objectForKey:@"inReplyTo"];
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	
	[messageField release];
	[charactersRemaining release];
	
	[messageContent release];
	[inReplyTo release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.messageField = nil;
}

- (void) viewDidLoad {
	[super viewDidLoad];
	
	// Message
	if (messageContent != nil) {
		messageField.text = messageContent;
		[self updateCharacterCountWithText:messageContent];
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
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (IBAction) close: (id) sender {
	if (popover != nil) {
		[popover dismissPopoverAnimated:YES];
		// Make sure delegate knows popover has been removed
		[popover.delegate popoverControllerDidDismissPopover:popover];
	} else {
		[self dismissModalViewControllerAnimated:YES];
	}
}

- (IBAction) send: (id) sender {
	// Check length
	NSString *text = messageField.text;
	// Convert the status to Unicode Normalized Form C to conform to Twitter's character counting requirement. See http://apiwiki.twitter.com/Counting-Characters .
	NSString *normalizedText = [text precomposedStringWithCanonicalMapping];
	if ((normalizedText.length == 0) || (normalizedText.length > kTwitterCharacterMax)) {
		return;
	}
	
	[twitter updateStatus:normalizedText inReplyTo:inReplyTo];
	
	self.messageContent = nil;
	self.inReplyTo = 0;
	[self close: nil];
}

#pragma mark -

- (void)textViewDidChange:(UITextView *)textView {
	[self updateCharacterCountWithText: textView.text];
}

- (void) updateCharacterCountWithText:(NSString *)text {
	// Convert the status to Unicode Normalized Form C to conform to Twitter's character counting requirement. See http://apiwiki.twitter.com/Counting-Characters .
	NSString *normalizationFormC = [text precomposedStringWithCanonicalMapping];
	int remaining = kTwitterCharacterMax - [normalizationFormC length];
	charactersRemaining.text = [NSString stringWithFormat:@"%d", remaining];
	if (remaining < 0) {
		charactersRemaining.textColor = [UIColor redColor];
	} else {
		charactersRemaining.textColor = [UIColor grayColor];
	}
	
	// Verify message length and account for Send button
	self.navigationItem.rightBarButtonItem.enabled = (([normalizationFormC length] != 0) && (remaining >= 0) && (twitter.currentAccount != nil));
}

@end
