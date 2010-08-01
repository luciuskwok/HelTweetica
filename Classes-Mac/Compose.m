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
#import "TwitterUpdateStatusAction.h"
#import "TwitterRetweetAction.h"



@implementation Compose
@synthesize textView, charactersRemaining, statusLabel;
@synthesize accountsPopUp, retweetStyleControl, shrinkURLButton, locationButton, tweetButton, pictureButton, activityIndicator;
@synthesize twitter, account, messageContent, inReplyTo, originalRetweetContent, newStyleRetweet;
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
	
	[twitter release];
	[account release];
	[messageContent release];
	[inReplyTo release];
	[originalRetweetContent release];
	
	[locationManager release];
	[actions release];
	
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

#pragma mark Network actions

- (void)addAction:(id)anAction {
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

- (void)removeAction:(id)anAction {
	[actions removeObject:anAction];
	
	if (actions.count == 0) {
		// Stop network activity indicator.
		[activityIndicator stopAnimation:nil];
		[activityIndicator setHidden: YES];
	}
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
		[locationManager startUpdatingLocation];
	} else {
		[locationManager stopUpdatingLocation];
	}
}

#pragma mark Send status update

- (void)startTwitterAction:(TwitterAction*)action {
	if (action == nil) return;
	
	// Add the action to the array of actions, and updates the network activity spinner
	[self addAction:action];
	
	// Set up Twitter action
	action.delegate = self;
	action.consumerToken = account.xAuthToken;
	action.consumerSecret = account.xAuthSecret;
	
	// Start the URL connection
	[action start];
}

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	[self removeAction:action];
	[delegate composeDidFinish:self];
	[[self window] performClose:nil];
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	[self removeAction: action];
	[tweetButton setEnabled:YES];
	[statusLabel setStringValue:[error localizedDescription]];
}


- (void)retweetMessageWithIdentifier:(NSNumber *)messageIdentifier {
	TwitterRetweetAction *action = [[[TwitterRetweetAction alloc] initWithMessageIdentifier:messageIdentifier] autorelease];
	[self startTwitterAction:action];
}	

- (void)updateStatus:(NSString *)text inReplyTo:(NSNumber *)reply location:(CLLocation *)location {
	TwitterUpdateStatusAction *action = [[[TwitterUpdateStatusAction alloc] initWithText:text inReplyTo:reply] autorelease];
	[action setLocation:location];
	[self startTwitterAction:action];
}

- (IBAction)tweet:(id)sender {
	// End editing of current text field and save to defaults
	[[self window] makeFirstResponder:[self window]];
	
	if (originalRetweetContent && newStyleRetweet) {
		// New-style retweet.
		[self retweetMessageWithIdentifier:inReplyTo];
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
			location = [locationManager location];
		}

		[self updateStatus:normalizedText inReplyTo:inReplyTo location:location];
	}
	
	// Disable button to prevent double-clicks.
	[tweetButton setEnabled:NO];
}


#pragma mark Accounts popup

- (IBAction)selectAccount:(id)sender {
	self.account = [sender representedObject];
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
	for (TwitterAccount *anAccount  in twitter.accounts) {
		NSMenuItem *item = [self menuItemWithTitle:anAccount.screenName action:@selector(selectAccount:) representedObject:anAccount indentationLevel:1];
		[accountsPopUp.menu addItem:item];
		if ([anAccount isEqual:account]) {
			[accountsPopUp selectItem:item];
		}
	}
}

- (void)accountsDidChange:(NSNotification*)notification {
	[self reloadAccountsPopUp];
}


#pragma mark URL shortening

- (IBAction)shrinkURLs:(id)sender {
	NSSet *shrinkActions = [LKShrinkURLAction actionsToShrinkURLsInString:[textView string]];
	
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
			NSString *text = [textView string];
			text = [text stringByReplacingOccurrencesOfString:longURL withString:shortURL];
			[self setTextViewContent:text];
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
	[statusLabel setStringValue:[error localizedDescription]];
}


#pragma mark Picture uploading

- (void)uploadPictureFile:(NSURL *)fileURL {
	// Get username and password from keychain.
	const char *cServiceName = "api.twitter.com";
	const char *cUser = [account.screenName cStringUsingEncoding:NSUTF8StringEncoding];
	void *cPass = nil;
	UInt32 cPassLength = 0;
	OSStatus err = SecKeychainFindGenericPassword(nil, strlen(cServiceName), cServiceName, strlen(cUser), cUser, &cPassLength, &cPass, nil);
	if (err != noErr) {
		[statusLabel setStringValue:NSLocalizedString (@"No password found for uploading!", @"status label")];
		return;
	}
	
	// Create and start action.
	LKUploadPictureAction *action = [[[LKUploadPictureAction alloc] initWithFile:fileURL] autorelease];
	action.delegate = self;
	action.username = account.screenName;
	action.password = [[[NSString alloc] initWithBytes:cPass length:cPassLength encoding:NSUTF8StringEncoding] autorelease];
	[action startUpload];
	[self addAction:action];
	
	// Clean up
	SecKeychainItemFreeContent (nil, cPass);
	if (err != noErr) {
		NSLog (@"SecKeychainItemFreeContent error %d.", err);
	}
}

- (void)action:(LKUploadPictureAction *)action didUploadPictureWithURL:(NSString *)url {
	NSString *text = [textView string];
	
	if ([text hasSuffix:@" "] == NO && [text hasSuffix:@"\n"] == NO && [text hasSuffix:@"\t"] == NO) 
		text = [text stringByAppendingString:@" "];
	text = [text stringByAppendingString:url];
	[self setTextViewContent:text];
	[self removeAction:action];
}

- (void)action:(LKUploadPictureAction *)action didFailWithErrorCode:(int)code description:(NSString *)description {
	[self removeAction:action];
	NSLog (@"Picture uploading failed with error: %@ (%d)", description, code);
	[statusLabel setStringValue:description];
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
	[locationManager stopUpdatingLocation];
	return YES;
}

@end
