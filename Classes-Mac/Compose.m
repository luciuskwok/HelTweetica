//
//  Compose.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/25/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "Compose.h"


@implementation Compose
@synthesize textField, charactersRemaining, tooLongLabel, retweetStyleControl, shrinkURLButton, locationButton, tweetButton, activityIndicator;
@synthesize messageContent, inReplyTo, originalRetweetContent, newStyleRetweet;
@synthesize delegate;


enum { kTwitterCharacterMax = 140 };


- (id)init {
	self = [self initWithWindowNibName:@"Compose"];
	if (self) {
		actions = [[NSMutableSet alloc] init];
	}
	return self;
}

- (void)dealloc {
	[messageContent release];
	[inReplyTo release];
	[originalRetweetContent release];
	
	[locationManager release];
	[actions release];
	
	[super dealloc];
}

- (void)windowDidLoad {
	// Message
	if (messageContent != nil) {
		[textField setStringValue:messageContent];
		[self updateCharacterCount];
	}
	
	// Location
	if ([CLLocationManager locationServicesEnabled]) {
		locationManager = [[CLLocationManager alloc] init];
		locationManager.distanceFilter = 45.0; // meters
		locationManager.desiredAccuracy = 15.0; // meters
		BOOL useLocation = [[NSUserDefaults standardUserDefaults] boolForKey:@"useLocation"];
		[locationButton setState:useLocation? NSOnState : NSOffState];
		if (useLocation) {
			[locationManager startUpdatingLocation];
		}
	} else {
		[locationButton setHidden:YES];
	}
	
	// Text field
	[textField becomeFirstResponder];
	NSText *text = textField.currentEditor;
	
	// Move insertion point to end of string.
	[text setSelectedRange: NSMakeRange (text.string.length, 0)];
	
	// Enable Continous Spelling
	NSTextView *textView = (NSTextView *)[self.window firstResponder];
	[textView setContinuousSpellCheckingEnabled:YES];
	
	// Retweet style
	if (originalRetweetContent != nil) {
		[self setNewStyleRetweet:newStyleRetweet];
	} else {
		[retweetStyleControl setHidden:YES];
	}
	
}


#pragma mark UI updating

- (void)updateCharacterCount {
	if (originalRetweetContent && newStyleRetweet) { // New-style RT doesn't require counting chars
		[charactersRemaining setStringValue: @""];
		[tooLongLabel setHidden:YES];
		[tweetButton setEnabled: YES];
	} else {
		// Convert the status to Unicode Normalized Form C to conform to Twitter's character counting requirement. See http://apiwiki.twitter.com/Counting-Characters .
		NSString *string = [textField stringValue];
		int remaining = kTwitterCharacterMax - [[string precomposedStringWithCanonicalMapping] length];
		[charactersRemaining setStringValue:[NSString stringWithFormat:@"%d", remaining]];
		if (remaining < 0) {
			[tooLongLabel setHidden:NO];
		} else {
			[tooLongLabel setHidden:YES];
		}
		// Verify message length and account for Send button
		[tweetButton setEnabled: (remaining < kTwitterCharacterMax) && (remaining >= 0)];
	}
}

- (void) setNewStyleRetweet:(BOOL)x {
	newStyleRetweet = x;
	
	// Update the RT Style segmented control.
	[retweetStyleControl setSelectedSegment: x ? 0 : 1];
	
	if (newStyleRetweet && originalRetweetContent) {
		// Reinstate original retweet message and disable editing
		[textField setStringValue: originalRetweetContent];
		[textField setEditable: NO];
		[textField setEnabled: NO];
		[shrinkURLButton setEnabled:NO];
		[locationButton setEnabled:NO];
	} else {
		// Allow editing
		[textField setEditable: YES];
		[textField setEnabled: YES];
 		[textField becomeFirstResponder];
		[shrinkURLButton setEnabled:YES];
		[locationButton setEnabled:YES];
	}
	
	[self updateCharacterCount];
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
	[self updateCharacterCount];
}


#pragma mark Sheet

- (void) askInWindow:(NSWindow *)aWindow modalDelegate:(id)del didEndSelector:(SEL)sel {
	[NSApp beginSheet: [self window] modalForWindow:aWindow modalDelegate:del didEndSelector:sel contextInfo:self];
}

- (void) endSheetWithReturnCode:(int)code {
	// End and close sheet
	NSWindow *aWindow = [self window];
	[NSApp endSheet: aWindow returnCode:code];
	[aWindow orderOut: self];
}


#pragma mark IBActions

- (IBAction)selectRetweetStyle:(id)sender {
	int index = [sender selectedSegment];
	self.newStyleRetweet = (index == 0);
}

- (IBAction)location:(id)sender {
	// Update button and defaults.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL useLocation = ![defaults boolForKey:@"useLocation"];
	[locationButton setState:useLocation? NSOnState : NSOffState];
	[defaults setBool:useLocation forKey:@"useLocation"];
	
	// Get location.
	if (useLocation) {
		[locationManager startUpdatingLocation];
	} else {
		[locationManager stopUpdatingLocation];
	}
}

- (IBAction)camera:(id)sender {
}

- (IBAction)tweet:(id)sender {
	// End editing of current text field and save to defaults
	[[self window] makeFirstResponder:[self window]];
	[self saveToUserDefaults];
	
	if (originalRetweetContent && newStyleRetweet) {
		// New-style retweet.
		[delegate compose:self didRetweetMessage:inReplyTo];
	} else { 
		// Normal tweets, replies, direct messages, and old-style retweets.
		
		// Check length
		NSString *text = [textField stringValue];
		NSString *normalizedText = [text precomposedStringWithCanonicalMapping];
		if ((normalizedText.length == 0) || (normalizedText.length > kTwitterCharacterMax)) {
			return;
		}
		
		// Location
		CLLocation *location = nil;
		if ([locationButton state] == NSOnState) {
			location = [locationManager location];
		}

		[delegate compose:self didSendMessage:normalizedText inReplyTo:inReplyTo location:location];
	}
	
	self.messageContent = nil;
	self.inReplyTo = nil;
	
	// Close sheet
	[self endSheetWithReturnCode:0];
}

- (IBAction)close:(id)sender {
	// End editing of current text field and save to defaults
	[[self window] makeFirstResponder:[self window]];
	[self saveToUserDefaults];
	
	// Location
	[locationManager stopUpdatingLocation];
	
	// Close sheet
	[self endSheetWithReturnCode:0];
}

#pragma mark URL shortening

- (IBAction)shrinkURLs:(id)sender {
	NSSet *shrinkActions = [LKShrinkURLAction actionsToShrinkURLsInString:[textField stringValue]];
	
	if (shrinkActions.count > 0) {
		for (LKShrinkURLAction *action in shrinkActions) {
			action.delegate = self;
			[action load];
		}
		
		// Start network activity indicator.
		[activityIndicator setHidden: NO];
		[activityIndicator startAnimation:nil];
		[actions unionSet:shrinkActions];
	}
}

- (void)removeAction:(LKLoadURLAction *)anAction {
	[actions removeObject:anAction];
	
	if (actions.count == 0) {
		// Stop network activity indicator.
		[activityIndicator stopAnimation:nil];
		[activityIndicator setHidden: YES];
	}
}	

- (void)shrinkURLAction:(LKShrinkURLAction *)anAction replacedLongURL:(NSString *)longURL withShortURL:(NSString *)shortURL {
	if (longURL != nil) {
		if ([shortURL hasPrefix:@"http"]) {
			NSString *text = [textField stringValue];
			text = [text stringByReplacingOccurrencesOfString:longURL withString:shortURL];
			[textField setStringValue:text];
		} else {
			// Log the error message
			NSLog (@"is.gd returned the error: %@", shortURL);
		}
	}
	[self removeAction:anAction];
}

- (void)shrinkURLAction:(LKShrinkURLAction*)anAction didFailWithError:(NSError*)error {
	NSLog (@"URL shrinker error: %@", error);
	[self removeAction:anAction];
}

#pragma mark Defaults

- (void)loadFromUserDefaults {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	self.messageContent = [defaults objectForKey:@"messageContent"];
	self.inReplyTo = [defaults objectForKey:@"inReplyTo"];
	self.originalRetweetContent = [defaults objectForKey:@"originalRetweetContent"];
	self.newStyleRetweet = [defaults boolForKey:@"newStyleRetweet"];
}

- (void)saveToUserDefaults {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [textField stringValue] forKey:@"messageContent"];
	[defaults setObject: inReplyTo forKey:@"inReplyTo"];
	[defaults setObject: originalRetweetContent forKey:@"originalRetweetContent"];
	[defaults setBool: newStyleRetweet forKey:@"newStyleRetweet"];
}	


@end
