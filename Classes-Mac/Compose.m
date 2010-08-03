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
#import "TwitterAccount.h"
#import "Twitter.h"


@implementation Compose
@synthesize textView, charactersRemaining, statusLabel;
@synthesize accountsPopUp, retweetStyleControl, shrinkURLButton, locationButton, tweetButton, pictureButton, activityIndicator;
@synthesize messageContent, inReplyTo, originalRetweetContent, newStyleRetweet;
@synthesize delegate;


enum { kTwitterCharacterMax = 140 };


- (id)initWithTwitter:(Twitter *)aTwitter account:(TwitterAccount *)anAccount {
	self = [self initWithWindowNibName:@"Compose"];
	if (self) {
		composer = [[TwitterComposer alloc] initWithTwitter:aTwitter account:anAccount];
		composer.delegate = self;
		
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
	
	[composer release];

	[messageContent release];
	[inReplyTo release];
	[originalRetweetContent release];
	
	[super dealloc];
}

#pragma mark NSCoding for saving app state
// Not working.

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [self init];
	if (self) {
		//self.senderScreenName = [aDecoder decodeObjectForKey:@"senderScreenName"];
		self.messageContent = [aDecoder decodeObjectForKey:@"messageContent"];
		self.inReplyTo = [aDecoder decodeObjectForKey:@"inReplyTo"];
		self.originalRetweetContent = [aDecoder decodeObjectForKey:@"originalRetweetContent"];
		[self.window setFrameAutosaveName: [aDecoder decodeObjectForKey:@"windowFrameAutosaveName"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	//[aCoder encodeObject:senderScreenName forKey:@"senderScreenName"];
	[aCoder encodeObject:messageContent forKey:@"messageContent"];
	[aCoder encodeObject:inReplyTo forKey:@"inReplyTo"];
	[aCoder encodeObject:originalRetweetContent forKey:@"originalRetweetContent"];
	[aCoder encodeObject:[self.window frameAutosaveName ] forKey:@"windowFrameAutosaveName"];
}

#pragma mark Composer delegate

- (void)composerDidStartNetworkAction:(TwitterComposer *)aComposer {
	[activityIndicator setHidden: NO];
	[activityIndicator startAnimation:nil];
}

- (void)composerDidFinishNetworkAction:(TwitterComposer *)aComposer {
	if ([aComposer numberOfNetworkActions] == 0) {
		// Stop network activity indicator.
		[activityIndicator stopAnimation:nil];
		[activityIndicator setHidden: YES];
	}
}

- (void)composerDidFinishSendingStatusUpdate:(TwitterComposer *)aComposer {
	[delegate composeDidFinish:self];
	[[self window] performClose:nil];
}

- (void)composer:(TwitterComposer *)aComposer didFailWithError:(NSError *)error {
	[tweetButton setEnabled:YES];
	[statusLabel setStringValue:[error localizedDescription]];
}

#pragma mark UI updating

- (void)setTextViewContent:(NSString *)string {
	// Set the content of the main text view, set the font to the standard font, and move the insertion point to the end.
	[textView setString:string];
	[textView setFont:[NSFont systemFontOfSize:13.0f]];
	[textView setSelectedRange: NSMakeRange (textView.string.length, 0)];
	[self updateCharacterCount];
}

- (void)updateCharacterCount {
	if (originalRetweetContent && newStyleRetweet) { // New-style RT doesn't require counting chars
		[charactersRemaining setStringValue: @""];
		[statusLabel setStringValue:@""];
		[tweetButton setEnabled: YES];
	} else {
		// Convert the status to Unicode Normalized Form C to conform to Twitter's character counting requirement. See http://apiwiki.twitter.com/Counting-Characters .
		NSString *string = [textView string];
		int remaining = kTwitterCharacterMax - [[string precomposedStringWithCanonicalMapping] length];
		[charactersRemaining setStringValue:[NSString stringWithFormat:@"%d", remaining]];
		if (remaining < 0) {
			[statusLabel setStringValue:NSLocalizedString (@"Too long!", "status label")];
		} else {
			[statusLabel setStringValue:@""];
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
		[self setTextViewContent:originalRetweetContent];
		[textView setEditable: NO];
		[shrinkURLButton setEnabled:NO];
		[locationButton setEnabled:NO];
		[pictureButton setEnabled:NO];
	} else {
		// Allow editing
		[textView setEditable: YES];
 		[textView becomeFirstResponder];
		[shrinkURLButton setEnabled:YES];
		[locationButton setEnabled:YES];
		[pictureButton setEnabled:YES];
	}
	
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
		[composer.locationManager startUpdatingLocation];
	} else {
		[composer.locationManager stopUpdatingLocation];
	}
}

#pragma mark Send status update

- (IBAction)tweet:(id)sender {
	// End editing of current text field and save to defaults
	[[self window] makeFirstResponder:[self window]];
	
	if (originalRetweetContent && newStyleRetweet) {
		// New-style retweet.
		[composer retweetMessageWithIdentifier:inReplyTo];
	} else { 
		// Normal tweets, replies, direct messages, and old-style retweets.
		
		// Check length
		NSString *normalizedText = [[textView string] precomposedStringWithCanonicalMapping];
		if ((normalizedText.length == 0) || (normalizedText.length > kTwitterCharacterMax)) {
			return;
		}
		
		// Location
		CLLocation *location = nil;
		if ([locationButton state] == NSOnState) {
			location = [composer.locationManager location];
		}

		[composer updateStatus:normalizedText inReplyTo:inReplyTo location:location];
	}
	
	// Disable button to prevent double-clicks.
	[tweetButton setEnabled:NO];
}


#pragma mark Accounts popup

- (IBAction)selectAccount:(id)sender {
	composer.account = [sender representedObject];
}

- (NSMenuItem*)menuItemWithTitle:(NSString *)title action:(SEL)action representedObject:(id)representedObject indentationLevel:(int)indentationLevel {
	NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
	menuItem.title = title;
	menuItem.target = self;
	menuItem.action = action;
	menuItem.representedObject = representedObject;
	menuItem.indentationLevel = indentationLevel;
	return menuItem;
}	

- (void)reloadAccountsPopUp {
	const int kUsersMenuPresetItems = 0;
	
	// Remove all items after separator and insert screen names of all accounts.
	while (accountsPopUp.menu.numberOfItems > kUsersMenuPresetItems) {
		[accountsPopUp.menu removeItemAtIndex:kUsersMenuPresetItems];
	}
	
	// Insert
	for (TwitterAccount *anAccount  in composer.twitter.accounts) {
		NSMenuItem *item = [self menuItemWithTitle:anAccount.screenName action:@selector(selectAccount:) representedObject:anAccount indentationLevel:1];
		[accountsPopUp.menu addItem:item];
		if ([anAccount isEqual:composer.account]) {
			[accountsPopUp selectItem:item];
		}
	}
}

- (void)accountsDidChange:(NSNotification*)notification {
	[self reloadAccountsPopUp];
}

#pragma mark URL shrinking

- (IBAction)shrinkURLs:(id)sender {
	[composer shrinkURLsInString:[textView string]];
}

- (void)composer:(TwitterComposer *)aComposer didShrinkLongURL:(NSString *)longURL toShortURL:(NSString *)shortURL {
	NSString *text = [textView string];
	text = [text stringByReplacingOccurrencesOfString:longURL withString:shortURL];
	[self setTextViewContent:text];
}

#pragma mark Picture uploading

- (void)uploadPictureFile:(NSURL *)fileURL {
	// Load picture data.
	NSError *error = nil;
	NSData *pictureData = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMapped error:&error];
	if (pictureData == nil)
		NSLog (@"Error opening file %@: %@", fileURL, error);
	
	// Create and start action.
	[composer uploadPicture:pictureData withFileExtension:[fileURL pathExtension]];
	
}

- (void)composer:(TwitterComposer *)aComposer didUploadPictureWithURL:(NSString *)url {
	NSString *text = [textView string];
	if ([text hasSuffix:@" "] == NO && [text hasSuffix:@"\n"] == NO && [text hasSuffix:@"\t"] == NO) 
		text = [text stringByAppendingString:@" "];
	text = [text stringByAppendingString:url];
	[self setTextViewContent:text];
}

- (NSArray *)supportedImageTypes {
	return [NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"gif", @"tif", nil];
}

- (IBAction)addPicture:(id)sender {
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel beginSheetForDirectory:nil file:nil types:[self supportedImageTypes] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

 - (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo {
	 if (returnCode == NSOKButton) {
		 NSArray *files = [panel URLs];
		 if ([files count] > 0) {
			// Only open first file selected.
			 [self uploadPictureFile:[files objectAtIndex:0]];
		 }
	 }
 }

- (BOOL)uploadPictureFilesInText:(NSString *)string {
	// Detect file paths and turn them into picture uploads. Returns YES if a valid path was found.
	if (string.length > 4) {
		NSString *fileExt = [string pathExtension];
		if (fileExt != nil) {
			BOOL hasValidExtension = [[self supportedImageTypes] containsObject:fileExt];			
			if ([string hasPrefix:@"/"] && hasValidExtension) {
				[self uploadPictureFile:[NSURL fileURLWithPath:string]];
				return YES;
			}
		}
	}
	return NO;
}
	
#pragma mark Dragging

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	NSPasteboard *pboard;
	NSDragOperation sourceDragMask;
	
	sourceDragMask = [sender draggingSourceOperationMask];
	pboard = [sender draggingPasteboard];
	
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
		if (sourceDragMask & NSDragOperationCopy) {
			NSArray *fileTypes = [self supportedImageTypes];
			NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
			for (NSString *file in files) {
				if ([fileTypes containsObject:[file pathExtension]]) {
					return NSDragOperationCopy;
				}
			}
		}
	}
	return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
		NSArray *fileTypes = [self supportedImageTypes];
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
		for (NSString *file in files) {
			if ([fileTypes containsObject:[file pathExtension]]) {
				// Only use the first supported file.
				NSURL *url = [NSURL fileURLWithPath:file];
				[self uploadPictureFile:url];
				break;
			}
		}
	}
	return YES;
}

#pragma mark Composer delegate



#pragma mark Text view delegate

- (void)textDidChange:(NSNotification *)aNotification {
	[self updateCharacterCount];
}

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
	
	BOOL hasPicture = [self uploadPictureFilesInText:replacementString];
	return !hasPicture;
}

#pragma mark Window

- (void)windowDidLoad {
	// Message
	if (messageContent != nil) {
		[self setTextViewContent:messageContent];
	} else {
		[self setTextViewContent:@""];
	}
	
	// Location
	if (composer.locationManager) {
		BOOL useLocation = [[NSUserDefaults standardUserDefaults] boolForKey:@"useLocation"];
		[locationButton setState:useLocation? NSOnState : NSOffState];
		if (useLocation) {
			[composer.locationManager startUpdatingLocation];
		}
	} else {
		[locationButton setHidden:YES];
	}
	
	// Enable Continous Spelling
	[textView setContinuousSpellCheckingEnabled:YES];
	
	// Retweet style
	if (originalRetweetContent != nil) {
		[self setNewStyleRetweet:newStyleRetweet];
	} else {
		[retweetStyleControl setEnabled:NO];
	}
	
	// Accounts
	[self reloadAccountsPopUp];
	
	// Enable receiving dragged files in window.
	[self.window registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

- (BOOL)windowShouldClose:(id)sender {
	[composer cancelActions];
	[composer.locationManager stopUpdatingLocation];
	return YES;
}

@end
