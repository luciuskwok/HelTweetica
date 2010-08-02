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
#import "HelTweeticaAppDelegate.h"


const int kTwitterCharacterMax = 140;


@implementation ComposeViewController
@synthesize messageField, sendButton, retweetStyleButton, geotagButton, shrinkURLsButton, charactersRemaining, bottomToolbar;
@synthesize account, messageContent, inReplyTo, originalRetweetContent, newStyleRetweet;
@synthesize locationManager, delegate;


- (id)initWithAccount:(TwitterAccount*)anAccount {
	if (self = [super initWithNibName:@"Compose" bundle:nil]) {
		// Twitter
		self.account = anAccount;
		appDelegate = [[UIApplication sharedApplication] delegate];
		
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
			[self setContentSizeForViewInPopover: CGSizeMake(480, 275)];
		}
		
	}
	return self;
}

- (void)dealloc {
	[messageField release];
	[sendButton release];
	[retweetStyleButton release];
	[geotagButton release];
	[shrinkURLsButton release];
	[charactersRemaining release];
	[bottomToolbar release];
	
	[account release];
	[messageContent release];
	[inReplyTo release];
	[originalRetweetContent release];
	
	[locationManager release];
	
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
	return newStyleRetweet ? NSLocalizedString (@"New RT", "button") : NSLocalizedString (@"Old RT", "button");
}

- (void)updateGeotagButton {
	BOOL locationEnabled = locationManager.locationServicesEnabled;
	BOOL geotag = [[NSUserDefaults standardUserDefaults] boolForKey:@"geotag"];
	NSString *on = NSLocalizedString (@"Geotag ON", @"button");
	NSString *off = NSLocalizedString (@"Geotag off", @"button");
	
	if (locationEnabled) {
		[geotagButton setTitle: geotag? on : off];
		geotagButton.enabled = YES;
	} else {
		[geotagButton setTitle: off];
		geotagButton.enabled = NO;
	}
}

- (void) setNewStyleRetweet:(BOOL)x {
	newStyleRetweet = x;
	self.retweetStyleButton.title = [self retweetStyleButtonTitle];
	if (newStyleRetweet && originalRetweetContent) {
		// Reinstate original retweet message and disable editing
		messageField.text = originalRetweetContent;
		messageField.textColor = [UIColor grayColor];
		messageField.editable = NO;
		geotagButton.enabled = NO;
		shrinkURLsButton.enabled = NO;
	} else {
		// Allow editing
		messageField.editable = YES;
		messageField.textColor = [UIColor blackColor];
		geotagButton.enabled = YES;
		shrinkURLsButton.enabled = YES;
		[self updateCharacterCountWithText: messageField.text];
		[messageField becomeFirstResponder];
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
	
	// Geotag
	self.locationManager = [[[CLLocationManager alloc] init] autorelease];
	locationManager.distanceFilter = 45.0; // meters
	locationManager.desiredAccuracy = 15.0; // meters
	BOOL geotag = [[NSUserDefaults standardUserDefaults] boolForKey:@"geotag"];
	if (geotag) {
		[locationManager startUpdatingLocation];
	}
	[self updateGeotagButton];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	self.messageField = nil;
	self.charactersRemaining = nil;
	self.retweetStyleButton = nil;
	self.locationManager = nil;
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

#pragma mark IBActions

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
		BOOL geotag = [[NSUserDefaults standardUserDefaults] boolForKey:@"geotag"];
		if (geotag) {
			location = [locationManager location];
		}
		
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

- (IBAction)geotag:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL geotag = [defaults boolForKey:@"geotag"];
	[defaults setBool:!geotag forKey:@"geotag"];
	[self updateGeotagButton];
	if (geotag) {
		[locationManager startUpdatingLocation];
	} else {
		[locationManager stopUpdatingLocation];
	}
}

- (IBAction) toggleRetweetStyle: (id) sender {
	self.newStyleRetweet = !newStyleRetweet;
	[self updateCharacterCountWithText:messageField.text];
}

- (IBAction)camera:(id)sender {
}

#pragma mark Shrink URLs

- (IBAction)shrinkURLs:(id)sender {
	NSSet *shrinkActions = [LKShrinkURLAction actionsToShrinkURLsInString:messageField.text];
	
	if (shrinkActions.count > 0) {
		for (LKShrinkURLAction *action in shrinkActions) {
			action.delegate = self;
			[action load];
			[appDelegate incrementNetworkActionCount];
		}
	}
}

- (void)action:(LKShrinkURLAction *)anAction didReplaceLongURL:(NSString *)longURL withShortURL:(NSString *)shortURL {
	if (longURL != nil) {
		if ([shortURL hasPrefix:@"http"]) {
			messageField.text = [messageField.text stringByReplacingOccurrencesOfString:longURL withString:shortURL];
		} else {
			// Log the error message
			NSLog (@"is.gd returned the error: %@", shortURL);
		}
	}
	[appDelegate decrementNetworkActionCount];
}

- (void)action:(LKShrinkURLAction*)anAction didFailWithError:(NSError*)error {
	NSLog (@"URL shrinker error: %@", error);
	[appDelegate decrementNetworkActionCount];
}

#pragma mark Text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
	[self updateCharacterCountWithText: textView.text];
}

@end
