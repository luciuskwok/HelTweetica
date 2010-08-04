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
#import "TwitterUpdateStatusAction.h"
#import "TwitterRetweetAction.h"
#import "TwitterAccount.h"
#import "Twitter.h"



const int kTwitterCharacterMax = 140;


@implementation ComposeViewController
@synthesize messageField;
@synthesize topToolbar, retweetStyleButton, accountButton, sendButton;
@synthesize inputToolbar, geotagButton, charactersRemaining;
@synthesize currentPopover, currentActionSheet, delegate;


- (id)initWithAccount:(TwitterAccount*)anAccount {
	if (self = [super initWithNibName:@"Compose" bundle:nil]) {
		appDelegate = [[UIApplication sharedApplication] delegate];
		composer = [[TwitterComposer alloc] initWithTwitter:appDelegate.twitter account:anAccount];
		composer.delegate = self;
		
		// Title
		if (anAccount.screenName == nil) {
			self.navigationItem.title = @"—";
		} else {
			self.navigationItem.title = anAccount.screenName;
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
		
		// Modal presentation style
		self.modalPresentationStyle = UIModalPresentationFormSheet;
	}
	return self;
}

- (void)dealloc {
	[messageField release];
	
	[topToolbar release];
	[retweetStyleButton release];
	[accountButton release];
	[sendButton release];

	[inputToolbar release];
	[geotagButton release];
	[charactersRemaining release];
	
	[composer release];
	currentPopover.delegate = nil;
	[currentPopover release];
	currentActionSheet.delegate = nil;
	[currentActionSheet release];
	
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (void)resetMessageContent {
	// Remove user defaults for message content.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:@"messageContent"];
	[defaults removeObjectForKey:@"inReplyTo"];
	[defaults removeObjectForKey:@"originalRetweetContent"];
}

#pragma mark Popovers

- (BOOL)closeAllPopovers {
	// Returns YES if it closes a popover.
	if (currentActionSheet != nil) {
		[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
		self.currentActionSheet = nil;
		return YES;
	}
	if (currentPopover != nil) {
		[currentPopover dismissPopoverAnimated:YES];
		self.currentPopover = nil;
		return YES;
	}
	return NO;
}

- (void)popoverControllerDidDismissPopover: (UIPopoverController *) popoverController {
	self.currentPopover = nil;
}

- (UIPopoverController*) presentViewController:(UIViewController*)vc inPopoverFromItem:(UIBarButtonItem*)item {
	// Present popover
	UIPopoverController *popover = [[[NSClassFromString(@"UIPopoverController") alloc] initWithContentViewController:vc] autorelease];
	popover.delegate = self;
	[popover presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	self.currentPopover = popover;
	return popover;
}	

- (void) presentViewController:(UIViewController*)viewController inNavControllerInPopoverFromItem: (UIBarButtonItem*) item {
	UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController: viewController] autorelease];
	[self presentViewController:navController inPopoverFromItem:item];
}

#pragma mark UI updating

- (void)updateAccountButton {
	NSString *prefix = NSLocalizedString (@"From: ", @"prefix");
	accountButton.title = [prefix stringByAppendingString:composer.account.screenName];
}

- (void)updateRetweetStyle {
	NSString *originalRetweetContent = [[NSUserDefaults standardUserDefaults] objectForKey:@"originalRetweetContent"];
	BOOL newStyleRetweet = [[NSUserDefaults standardUserDefaults] boolForKey:@"newStyleRetweet"];

	// Retweet style button.
	if (originalRetweetContent) {
		if (newStyleRetweet) {
			retweetStyleButton.title = NSLocalizedString (@"RT style: New", "button");
		} else {
			retweetStyleButton.title = NSLocalizedString (@"RT style: Old", "button");
		}
		retweetStyleButton.enabled = YES;
	} else {
		// Remove RT button from toolbar.
		NSMutableArray *items = [NSMutableArray arrayWithArray:topToolbar.items];
		if ([items containsObject:retweetStyleButton]) {
			[items removeObject:retweetStyleButton];
			topToolbar.items = items;
		}
	}
	
	// Message field and controls.
	if (newStyleRetweet && originalRetweetContent) {
		// Reinstate original retweet message and disable editing
		messageField.text = originalRetweetContent;
		messageField.textColor = [UIColor grayColor];
		messageField.editable = NO;
		charactersRemaining.title = @"";
		sendButton.enabled = YES;
	} else {
		// Allow editing
		messageField.editable = YES;
		messageField.textColor = [UIColor blackColor];
		messageField.inputAccessoryView = inputToolbar;
		[messageField becomeFirstResponder];
		[self updateCharacterCountWithText: messageField.text];
	}
	
	// Input toolbar.
	for (id item in inputToolbar.items) {
		[item setEnabled:messageField.editable];
	}
}

- (void)updateGeotagButton {
	BOOL locationEnabled = (composer.locationManager != nil);
	BOOL geotag = [[NSUserDefaults standardUserDefaults] boolForKey:@"geotag"];
	NSString *on = NSLocalizedString (@"Geotag: ON", @"button");
	NSString *off = NSLocalizedString (@"Geotag: off", @"button");
	NSString *na = NSLocalizedString (@"Geotag: n/a", @"button");
	
	if (locationEnabled) {
		[geotagButton setTitle: geotag? on : off];
		geotagButton.enabled = YES;
	} else {
		[geotagButton setTitle: na];
		geotagButton.enabled = NO;
	}
}

- (void) updateCharacterCountWithText:(NSString *)text {
	// Convert the status to Unicode Normalized Form C to conform to Twitter's character counting requirement. See http://apiwiki.twitter.com/Counting-Characters .
	NSString *normalizationFormC = [text precomposedStringWithCanonicalMapping];
	int remaining = kTwitterCharacterMax - [normalizationFormC length];
	if (remaining < 0) {
		charactersRemaining.title = [NSString stringWithFormat:@"Too long! %d", remaining];
	} else {
		charactersRemaining.title = [NSString stringWithFormat:@"%d", remaining];
	}
	// Verify message length and account for Send button
	sendButton.enabled = (([normalizationFormC length] != 0) && (remaining >= 0) && (composer.account != nil));
}

#pragma mark Composer delegate

- (void)composerDidStartNetworkAction:(TwitterComposer *)aComposer {
	[appDelegate incrementNetworkActionCount];
}

- (void)composerDidFinishNetworkAction:(TwitterComposer *)aComposer {
	[appDelegate decrementNetworkActionCount];
}

- (void)composerDidFinishSendingStatusUpdate:(TwitterComposer *)aComposer {
	[delegate composeDidFinish:self];
	[self resetMessageContent];
}

- (void)composer:(TwitterComposer *)aComposer didFailWithError:(NSError *)error {
	UIAlertView *alert = [[[UIAlertView alloc] init] autorelease];
	alert.title = NSLocalizedString (@"Network error", @"title");
	alert.message = [error localizedDescription];
	[alert addButtonWithTitle: NSLocalizedString (@"OK", @"button")];
	[alert show];
}	

#pragma mark IBActions

- (IBAction) send: (id) sender {
	[self closeAllPopovers];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *originalRetweetContent = [defaults objectForKey:@"originalRetweetContent"];
	BOOL newStyleRetweet = [defaults boolForKey:@"newStyleRetweet"];
	NSNumber *inReplyTo = [defaults objectForKey:@"inReplyTo"];
	
	// Save message content to defaults.
	[defaults setObject:messageField.text forKey:@"messageContent"];
	
	// Cancel any URL shortening or picture uploading
	[composer cancelActions];
	[composer.locationManager stopUpdatingLocation];
	
	if (originalRetweetContent && newStyleRetweet) {
		// New-style retweet.
		[composer retweetMessageWithIdentifier:inReplyTo];
	} else {
		// Normal tweets, replies, direct messages, and old-style retweets.

		// Check length
		NSString *normalizedText = [messageField.text precomposedStringWithCanonicalMapping];
		if ((normalizedText.length == 0) || (normalizedText.length > kTwitterCharacterMax))
			return;
		
		// Location
		BOOL geotag = [defaults boolForKey:@"geotag"];
		CLLocation *location = geotag? [composer.locationManager location] : nil;
		
		[composer updateStatus:normalizedText inReplyTo:inReplyTo location:location];
	}
	
	// Close but don't cancel actions
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction) close: (id) sender {
	// Save message content to defaults.
	[[NSUserDefaults standardUserDefaults] setObject:messageField.text forKey:@"messageContent"];

	[self closeAllPopovers];
	[composer cancelActions];
	[composer.locationManager stopUpdatingLocation];
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction) toggleRetweetStyle: (id) sender {
	[self closeAllPopovers];
	
	BOOL newStyleRetweet = [[NSUserDefaults standardUserDefaults] boolForKey:@"newStyleRetweet"];
	[[NSUserDefaults standardUserDefaults] setBool:!newStyleRetweet forKey:@"newStyleRetweet"];
	[self updateRetweetStyle];
}

- (IBAction)toggleGeotag:(id)sender {
	[self closeAllPopovers];
	
	BOOL geotag = [[NSUserDefaults standardUserDefaults] boolForKey:@"geotag"];
	[[NSUserDefaults standardUserDefaults] setBool:!geotag forKey:@"geotag"];
	[self updateGeotagButton];

	if (geotag) {
		[composer.locationManager startUpdatingLocation];
	} else {
		[composer.locationManager stopUpdatingLocation];
	}
}

- (IBAction) clear: (id) sender {
	[self closeAllPopovers];
	
	[self resetMessageContent];
	messageField.text = @"";
	[self updateCharacterCountWithText:@""];
	[self updateRetweetStyle];
}

#pragma mark Accounts

- (IBAction)chooseAccount:(id)sender {
	[self closeAllPopovers];
	
	UIActionSheet *actionSheet = [[[UIActionSheet alloc] init] autorelease];
	actionSheet.delegate = self;
	for (TwitterAccount *anAccount in appDelegate.twitter.accounts) {
		[actionSheet addButtonWithTitle:anAccount.screenName];
	}
	[actionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex < 0 || buttonIndex >= appDelegate.twitter.accounts.count) return;
	
	composer.account = [composer.twitter.accounts objectAtIndex:buttonIndex];
	[self updateAccountButton];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (actionSheet == self.currentActionSheet)
		self.currentActionSheet = nil;
}

#pragma mark Pictures

- (IBAction)addPicture:(id)sender {
	if ([self closeAllPopovers] == NO) {
		if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] == NO) {
			// Show error alert.
			UIAlertView *alert = [[[UIAlertView alloc] init] autorelease];
			alert.title = NSLocalizedString (@"Photo library not available", @"title");
			alert.message = NSLocalizedString (@"Pictures cannot be added at this time.", @"text");
			[alert addButtonWithTitle:NSLocalizedString (@"Cancel", @"button")];
			[alert show];
			return;
		}
		
		UIImagePickerController *picker = [[[UIImagePickerController alloc] init] autorelease];
		picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
		picker.delegate = self;
	
		[self presentViewController:picker inPopoverFromItem:sender];
	}
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[self closeAllPopovers];
	
	// Try to get the original file.
	NSURL *originalFile = [info objectForKey:UIImagePickerControllerMediaURL];
	if (originalFile) {
		[composer uploadPicture:[NSData dataWithContentsOfURL:originalFile] withFileExtension:[[originalFile absoluteString] pathExtension]];
		return;
	}

	// Get the edited or original image
	UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
	if (image == nil)
		image = [info objectForKey:UIImagePickerControllerOriginalImage];
	
	if (image != nil) {
		// Upload image to hosting service.
		const CGFloat kMaxQuality = 1.0f;
		const CGFloat kMinQuality = 0.1f;
		const CGFloat kQualityRange = kMaxQuality - kMinQuality;
		const CGFloat kMinByteSize = 2 * 1024 * 1024; // 2 MB
		const CGFloat kMaxByteSize = 20 * 1024 * 1024; // 20 MB
		const CGFloat kByteSizeDomain = kMaxByteSize - kMinByteSize;
		CGFloat raw = image.size.width * image.size.height * 4.0f;
		CGFloat x = 1.0f - (raw - kMinByteSize) / kByteSizeDomain;
		if (x < 0.0f)
			x = 0.0f;
		
		CGFloat qualtiy = x * x * kQualityRange + kMinQuality;
		if (qualtiy > kMaxQuality)
			qualtiy = kMaxQuality;
		if (qualtiy < kMinQuality)
			qualtiy = kMinQuality;
		NSData *jpgData = UIImageJPEGRepresentation(image, qualtiy);
		if (jpgData) {
			[composer uploadPicture:jpgData withFileExtension:@"jpg"];
		}
		// Testing
		// TODO: remove test code before release.
		//NSLog(@"Image size: %1.0fx%1.0f, raw %1.2f Kb, jpeg %1.2f Kb, quality %1.2f.", image.size.width, image.size.height, raw/1024.0f, jpgData.length/1024.0f, qualtiy );
	} else {
		// Show error alert.
		UIAlertView *alert = [[[UIAlertView alloc] init] autorelease];
		alert.title = NSLocalizedString (@"Image Error", @"title");
		alert.message = NSLocalizedString (@"The selected image could not be imported.", @"text");
		[alert addButtonWithTitle:NSLocalizedString (@"Cancel", @"button")];
		[alert show];
	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[self closeAllPopovers];
}

- (void)composer:(TwitterComposer *)aComposer didUploadPictureWithURL:(NSString *)url {
	NSString *text = messageField.text;
	if ([text hasSuffix:@" "] == NO && [text hasSuffix:@"\n"] == NO && [text hasSuffix:@"\t"] == NO) 
		text = [text stringByAppendingString:@" "];
	messageField.text = [text stringByAppendingString:url];
	[self updateCharacterCountWithText:text];
}

#pragma mark URL shrinking

- (IBAction)shrinkURLs:(id)sender {
	[composer shrinkURLsInString:messageField.text];
}

- (void)composer:(TwitterComposer *)aComposer didShrinkLongURL:(NSString *)longURL toShortURL:(NSString *)shortURL {
	messageField.text = [messageField.text stringByReplacingOccurrencesOfString:longURL withString:shortURL];
	[self updateCharacterCountWithText:messageField.text];
}

#pragma mark View lifecycle

- (void) viewDidLoad {
	[super viewDidLoad];

	// From: Account.
	[self updateAccountButton];
	
	// Message field.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *text = [defaults objectForKey:@"messageContent"];
	if (text != nil) {
		messageField.text = text;
		[self updateCharacterCountWithText:text];
	}
	
	// Retweet style. Remove  button if it's not applicable.
	[self updateRetweetStyle];
	
	
	// Geotag
	BOOL geotag = [defaults boolForKey:@"geotag"];
	if (geotag)
		[composer.locationManager startUpdatingLocation];
	[self updateGeotagButton];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	self.messageField = nil;
	
	self.topToolbar = nil;
	self.retweetStyleButton = nil;
	self.accountButton = nil;
	self.sendButton = nil;
	
	self.inputToolbar = nil;
	self.geotagButton = nil;
	self.charactersRemaining = nil;
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.messageField becomeFirstResponder];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark Text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
	[self updateCharacterCountWithText: textView.text];
}

@end
