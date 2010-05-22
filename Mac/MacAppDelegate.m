//
//  MacAppDelegate.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/21/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MacAppDelegate.h"


@implementation MacAppDelegate
@synthesize window, webView, twitter;

- (void)dealloc {
	[window release];
	[webView release];
	[twitter release];
	[super dealloc];
}

- (void)awakeFromNib {
	twitter = [[Twitter alloc] init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Create HTML to display
	NSMutableString *html = [NSMutableString string];
	[html appendString:@"<b>Some</b> text."];
	
	
	// Use the app bundle as the base URL
	NSString *mainBundle = [[NSBundle mainBundle] bundlePath];
	NSURL *baseURL = [NSURL fileURLWithPath:mainBundle];
	
	// Load HTML into main frame
	WebFrame *webFrame = [webView mainFrame];
	[webFrame loadHTMLString:html baseURL:baseURL];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[twitter save];
}

- (void) incrementNetworkActionCount {
	networkActionCount++;
	// TODO: add a network activity spinner
	//[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void) decrementNetworkActionCount {
	networkActionCount--;
	if (networkActionCount <= 0) {
		networkActionCount = 0;
		// TODO: add a network activity spinner
		//[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
}

@end
