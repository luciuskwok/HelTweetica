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
@synthesize textField, charactersRemaining, tooLongLabel, retweetStyleControl, shrinkURLButton, locationButton, tweetButton, pictureButton, activityIndicator;
@synthesize senderScreenName, messageContent, inReplyTo, originalRetweetContent, newStyleRetweet;
@synthesize delegate;


enum { kTwitterCharacterMax = 140 };


- (id)init {
	self = [self initWithWindowNibName:@"Compose"];
	if (self) {
		actions = [[NSMutableSet alloc] init];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		newStyleRetweet = [defaults boolForKey:@"newStyleRetweet"];

		// Listen for changes to Twitter state data
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(accountsDidChange:) name:@"accountsDidChange" object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[senderScreenName release];
	[messageContent release];
	[inReplyTo release];
	[originalRetweetContent release];
	
	[locationManager release];
	[actions release];
	
	[super dealloc];
}

#pragma mark NSCoding for saving app state

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [self init];
	if (self) {
		self.senderScreenName = [aDecoder decodeObjectForKey:@"senderScreenName"];
		self.messageContent = [aDecoder decodeObjectForKey:@"messageContent"];
		self.inReplyTo = [aDecoder decodeObjectForKey:@"inReplyTo"];
		self.originalRetweetContent = [aDecoder decodeObjectForKey:@"originalRetweetContent"];
		[self.window setFrameAutosaveName: [aDecoder decodeObjectForKey:@"windowFrameAutosaveName"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:senderScreenName forKey:@"senderScreenName"];
	[aCoder encodeObject:messageContent forKey:@"messageContent"];
	[aCoder encodeObject:inReplyTo forKey:@"inReplyTo"];
	[aCoder encodeObject:originalRetweetContent forKey:@"originalRetweetContent"];
	[aCoder encodeObject:[self.window frameAutosaveName ] forKey:@"windowFrameAutosaveName"];
}

#pragma mark Window

- (void)windowDidLoad {
	// Message
	if (messageContent != nil) {
		[textField setStringValue:messageContent];
		[self updateCharacterCount];
	}
	
	// Location
	if ([CLLocationManager locationServicesEnabled]) {
		locationManager = [[CLLocationManager alloc] init];
		locationManager.distanceFilter = 100.0; // meters
		locationManager.desiredAccuracy = 30.0; // meters
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
		[retweetStyleControl setEnabled:NO];
	}
	
	// Enable receiving dragged files in window.
	[self.window registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
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
		[pictureButton setEnabled:NO];
	} else {
		// Allow editing
		[textField setEditable: YES];
		[textField setEnabled: YES];
 		[textField becomeFirstResponder];
		[shrinkURLButton setEnabled:YES];
		[locationButton setEnabled:YES];
		[pictureButton setEnabled:YES];
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
	[[NSUserDefaults standardUserDefaults] setBool: newStyleRetweet forKey:@"newStyleRetweet"];
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

- (IBAction)addPicture:(id)sender {
}

- (IBAction)tweet:(id)sender {
	// End editing of current text field and save to defaults
	[[self window] makeFirstResponder:[self window]];
	
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
	
	// Location
	[locationManager stopUpdatingLocation];
	
	// Close sheet
	[self endSheetWithReturnCode:0];
}

#pragma mark Network actions

- (void)addAction:(LKLoadURLAction *)anAction {
	// Start network activity indicator.
	[activityIndicator setHidden: NO];
	[activityIndicator startAnimation:nil];
	[actions addObject:anAction];
}

- (void)addActionsFromSet:(NSSet *)set {
	// Start network activity indicator.
	[activityIndicator setHidden: NO];
	[activityIndicator startAnimation:nil];
	[actions unionSet:set];
}

- (void)removeAction:(LKLoadURLAction *)anAction {
	[actions removeObject:anAction];
	
	if (actions.count == 0) {
		// Stop network activity indicator.
		[activityIndicator stopAnimation:nil];
		[activityIndicator setHidden: YES];
	}
}	

#pragma mark URL shortening

- (IBAction)shrinkURLs:(id)sender {
	NSSet *shrinkActions = [LKShrinkURLAction actionsToShrinkURLsInString:[textField stringValue]];
	
	if (shrinkActions.count > 0) {
		for (LKShrinkURLAction *action in shrinkActions) {
			action.delegate = self;
			[action load];
		}
		[self addActionsFromSet:shrinkActions];
	}
}

- (void)action:(LKShrinkURLAction *)anAction didReplaceLongURL:(NSString *)longURL withShortURL:(NSString *)shortURL {
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

- (void)action:(LKShrinkURLAction*)anAction didFailWithError:(NSError*)error {
	NSLog (@"URL shrinker error: %@", error);
	[self removeAction:anAction];
}


#pragma mark Picture uploading

- (void)uploadPictureData:(NSData *)data {
	// Get username and password from keychain.
	const char *cServiceName = "api.twitter.com";
	const char *cUser = [senderScreenName cStringUsingEncoding:NSUTF8StringEncoding];
	void *cPass = nil;
	UInt32 cPassLength = 0;
	OSStatus err = SecKeychainFindGenericPassword(nil, strlen(cServiceName), cServiceName, strlen(cUser), cUser, &cPassLength, &cPass, nil);
	if (err != noErr) {
		// Should put an error message in the status bar or somewhere.
		NSLog (@"Password not found for picture uploading. Error %d.", err);
		return;
	}
	
	// Create and start action.
	LKUploadPictureAction *action = [[[LKUploadPictureAction alloc] init] autorelease];
	action.username = senderScreenName;
	action.password = [[[NSString alloc] initWithBytes:cPass length:cPassLength encoding:NSUTF8StringEncoding] autorelease];
	action.media = data;
	[action startUpload];
	[self addAction:action];
	
	// Clean up
	SecKeychainItemFreeContent (nil, cPass);
	if (err != noErr) {
		NSLog (@"SecKeychainItemFreeContent error %d.", err);
	}
}

- (void)action:(LKUploadPictureAction *)action didUploadPictureWithURL:(NSString *)url {
	NSString *text = [textField stringValue];
	if ([text hasSuffix:@" "] == NO && [text hasSuffix:@"\n"] == NO && [text hasSuffix:@"\t"] == NO) 
		text = [text stringByAppendingString:@" "];
	text = [text stringByAppendingString:url];
	[textField setStringValue:text];
	
	[self removeAction:action];
}

- (void)action:(LKUploadPictureAction *)action didFailWithErrorCode:(int)code description:(NSString *)description {
	NSLog (@"Picture uploading failed with error: %@ (%d)", description, code);
	[self removeAction:action];
}

#pragma mark Dragging

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	NSPasteboard *pboard;
	NSDragOperation sourceDragMask;
	
	sourceDragMask = [sender draggingSourceOperationMask];
	pboard = [sender draggingPasteboard];
	
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
		if (sourceDragMask & NSDragOperationCopy) {
			return NSDragOperationCopy;
		}
	}
	return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
		if (files.count > 0) {
			// Only use the first file.
			NSString *file = [files objectAtIndex:0];
			NSError *error = nil;
			NSData *data = [NSData dataWithContentsOfFile:file options:NSDataReadingMapped error:&error];
			if (data == nil) {
				NSLog (@"Error opening file %@: %@", file, error);
			} else {
				[self uploadPictureData:data];
			}
		}
	}
	return YES;
}

#pragma mark Text field delegate

- (BOOL)control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector {
	if (commandSelector == @selector(insertNewline:)) {
		// new line action: always insert a line-break character and don’t cause the receiver to end editing
		[textView insertNewlineIgnoringFieldEditor:self];
		return YES;
	} else if (commandSelector == @selector(insertTab:)) {
		// tab action: always insert a tab character and don’t cause the receiver to end editing
		[textView insertTabIgnoringFieldEditor:self];
		return YES;
	}
	return NO;
}


@end
