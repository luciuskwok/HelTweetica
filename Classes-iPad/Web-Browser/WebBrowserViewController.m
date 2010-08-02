    //
//  WebBrowserViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "WebBrowserViewController.h"
#import "InstapaperSettingsViewController.h"
#import "Instapaper.h"
#import "HelTweeticaAppDelegate.h"


enum {
	kInstapaperActionSheetTag = 1,
	kActionActionSheetTag = 2
};


@interface WebBrowserViewController (PrivateMethods)
- (void) updateButtons;
- (void) emailLink:(NSURL*)url;
- (void) saveToInstapaper;
- (void) showInstapaperSettings;
@end

@implementation WebBrowserViewController
@synthesize webView, backButton, forwardButton, stopButton, reloadButton, titleLabel, currentActionSheet, request;

- (id)initWithURLRequest:(NSURLRequest*)aRequest {
	if (self = [super initWithNibName:@"WebBrowser" bundle:nil]) {
		self.request = aRequest;
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(instapaperUsernameDidChange:) name:@"instapaperUsernameDidChange" object:nil];
		[nc addObserver:self selector:@selector(networkError:) name:@"instapaperNetworkError" object:nil];
		[nc addObserver:self selector:@selector(authenticationFailed:) name:@"instapaperAuthenticationFailed" object:nil];
		[nc addObserver:self selector:@selector(instapaperSuccess:) name:@"instapaperSuccess" object:nil];
		appDelegate = [[UIApplication sharedApplication] delegate];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	webView.delegate = nil;
	[webView release];
	[backButton release];
	[forwardButton release];
	[stopButton release];
	[reloadButton release];
	[titleLabel release];
	
	[currentActionSheet release];
	[request release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	webView.delegate = nil;
	self.webView = nil;
}

- (void) viewDidLoad {
	titleLabel.text = [request.URL absoluteString];
	
	[webView loadRequest: request];
	[self.navigationController setNavigationBarHidden: YES animated: NO];
	[super viewDidLoad];
}

- (void) viewWillDisappear:(BOOL)animated {
	//webView.delegate = nil;
	[webView stopLoading];
	[appDelegate decrementNetworkActionCount];
	[super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Overriden to allow any orientation.
	return YES;
}

#pragma mark -

- (NSURL *)currentURL {
	NSURL *currentURL = [webView.request URL];
	if (currentURL.absoluteString.length == 0) 
		currentURL = [request URL];
	return currentURL;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView {
	titleLabel.text = [[self currentURL] absoluteString];
	[appDelegate incrementNetworkActionCount];
	[self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
	titleLabel.text = [[self currentURL] absoluteString];
	[appDelegate decrementNetworkActionCount];
	[self updateButtons];
}

- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error {
	[appDelegate decrementNetworkActionCount];
	[self updateButtons];
	
	if ([error code] != -999) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString localizedStringWithFormat:@"Error %d", [error code]] message:[NSString localizedStringWithFormat:@"The page could not be loaded: \"%@\"", [error localizedDescription]] delegate:nil cancelButtonTitle:[NSString localizedStringWithFormat:@"OK"] otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

- (void)updateButtons {
	backButton.enabled = [webView canGoBack];
	forwardButton.enabled = [webView canGoForward];
	stopButton.enabled = [webView isLoading];
	reloadButton.enabled = ![webView isLoading];
}

- (BOOL)closeAllPopovers {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		// Close any action sheets
		if (currentActionSheet != nil) {
			[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
			self.currentActionSheet = nil;
			return YES;
		}
	}
	return NO;
}

#pragma mark -

- (IBAction)done: (id) sender {
	[self closeAllPopovers];
	[self.navigationController popViewControllerAnimated: YES];
}

- (IBAction)instapaper: (id) sender {
	if ([self closeAllPopovers] == NO) {
		NSString *cancelButton = NSLocalizedString (@"Cancel", @"alert button");
		NSString *saveButton = NSLocalizedString (@"Read Later", @"alert button");
		NSString *settingsButton = NSLocalizedString (@"Instapaper Settings...", @"alert button");
		UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle: cancelButton destructiveButtonTitle: nil otherButtonTitles: saveButton, settingsButton, nil];
		sheet.tag = kInstapaperActionSheetTag;
		
		if ([UIActionSheet instancesRespondToSelector:@selector(showFromBarButtonItem:animated:)]) {
			// iPad version shows popover from the button pressed.	
			[sheet showFromBarButtonItem:sender animated:YES];
		} else {
			// iPhone version:
			[sheet showInView:self.view];
		}
		
		self.currentActionSheet = sheet;
		[sheet release];
	}
}

- (IBAction)action: (id) sender {
	if ([self closeAllPopovers] == NO) {
		NSString *cancelButton = NSLocalizedString (@"Cancel", @"alert button");
		NSString *b0 = NSLocalizedString (@"Open in Safari", @"alert button");
		NSString *b1 = NSLocalizedString (@"Email URL", @"alert button");
		NSString *b2 = NSLocalizedString (@"Tweet URL", @"alert button");
		UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle: cancelButton destructiveButtonTitle: nil otherButtonTitles: b0, b1, b2, nil];
		sheet.tag = kActionActionSheetTag;
		
		if ([UIActionSheet instancesRespondToSelector:@selector(showFromBarButtonItem:animated:)]) {
			// iPad version shows popover from the button pressed.	
			[sheet showFromBarButtonItem:sender animated:YES];
		} else {
			// iPhone version:
			[sheet showInView:self.view];
		}
		
		self.currentActionSheet = sheet;
		[sheet release];
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSURL *currentURL = [webView.request URL];
	if (currentURL.absoluteString.length == 0) 
		currentURL = [request URL];
	
	if (actionSheet.tag == kInstapaperActionSheetTag) {
		if (buttonIndex == 0) { // Save
			[self saveToInstapaper];
		} else if (buttonIndex == 1) { // Settings
			// Call settings but don't automatically add URL to instapaper
			addURLToInstapaperWhenUsernameChanges = NO;
			[self showInstapaperSettings];
		}
	} else if (actionSheet.tag == kActionActionSheetTag) {
		switch (buttonIndex) {
			case 0: // Safari
				[[UIApplication sharedApplication] openURL: currentURL];
				break;
			default:
				break;
		}
		if (buttonIndex == 0) { // Safari
			[[UIApplication sharedApplication] openURL: currentURL];
		} else if (buttonIndex == 1) { // Email
			[self emailLink:currentURL];
		}
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (actionSheet == self.currentActionSheet)
		self.currentActionSheet = nil;
}

- (void) emailLink:(NSURL*)url {
	if ([MFMailComposeViewController canSendMail] == NO) {
		// Alert 
		NSString *t = NSLocalizedString (@"Cannot Send Mail", @"alert title");
		NSString *m = NSLocalizedString (@"Please set up Mail in Settings.", @"alert message");
		NSString *c = NSLocalizedString (@"Cancel.", @"alert button");
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:t message:m delegate:nil cancelButtonTitle:c otherButtonTitles:nil];
		[alert show];
		[alert release];
	} else {
		MFMailComposeViewController *picker = [[[MFMailComposeViewController alloc] init] autorelease];
		picker.mailComposeDelegate = self;

		// Add URL in email body.
		NSString *body = [NSString stringWithFormat:@"%@\n", [url absoluteString]];
		[picker setMessageBody:body isHTML:NO];
		[self presentModalViewController:picker animated:YES];
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {    
    [self dismissModalViewControllerAnimated:YES];
}

- (void) saveCurrentURLToInstapaper {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *instapaperUsername = [defaults objectForKey:@"instapaperUsername"];
	NSString *instapaperPassword = [defaults objectForKey:@"instapaperPassword"];

	[[Instapaper sharedInstapaper] addURL:[self currentURL] withUsername:instapaperUsername password:instapaperPassword];
}

- (void) saveToInstapaper {
	// Get Instapaper credentials
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *instapaperUsername = [defaults objectForKey:@"instapaperUsername"];
	
	if (instapaperUsername == nil) {
		addURLToInstapaperWhenUsernameChanges = YES; // If the login succeeds, automatically add the current URL.
		[self showInstapaperSettings];
	} else {
		[self saveCurrentURLToInstapaper];
	}
}

- (void) showInstapaperSettings {
	InstapaperSettingsViewController *settings = [[[InstapaperSettingsViewController alloc] init] autorelease];
	[self presentModalViewController:settings animated:YES];
}

- (void) instapaperUsernameDidChange: (NSNotification*) notification {
	if (addURLToInstapaperWhenUsernameChanges)
		[self saveCurrentURLToInstapaper];
}

#pragma mark -

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:aTitle message:aMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	[alert show];
}

- (void) authenticationFailed: (NSNotification*) aNotification {
	NSString *title = NSLocalizedString (@"Cannot Post to Instapaper", @"");
	NSString *message = NSLocalizedString (@"The Instapaper username or password is incorrect.", @"");
	[self showAlertWithTitle:title message:message];
}

- (void) networkError: (NSNotification*) aNotification {
	NSString *title = NSLocalizedString (@"Network error", @"");
	NSError *error = [aNotification object];
	[self showAlertWithTitle:title message:[error localizedDescription]];
}

- (void) instapaperSuccess: (NSNotification*) aNotification {
	NSString *title = NSLocalizedString (@"Saved to Instapaper!", @"");
	NSString *message = NSLocalizedString (@"This page was added to Instapaper for reading later.", @"");
	[self showAlertWithTitle:title message:message];
}

@end
