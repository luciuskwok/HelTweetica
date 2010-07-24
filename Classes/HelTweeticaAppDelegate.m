//
//  HelTweeticaAppDelegate.m
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


#import "HelTweeticaAppDelegate.h"
#import "Twitter.h"
#import "TwitterAccount.h"

#ifdef TARGET_PROJECT_MAC
#import "MainWindowController.h"
#import "PreferencesController.h"
#endif


@implementation HelTweeticaAppDelegate

#ifdef TARGET_PROJECT_MAC
#pragma mark Mac version

@synthesize twitter, windowControllers;

- (void)dealloc {
	[twitter release];
	[windowControllers release];
	[preferences release];
	[super dealloc];
}

- (void)awakeFromNib {
	twitter = [[Twitter alloc] init];
	windowControllers = [[NSMutableSet alloc] init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Reload previous window states
	NSData *windowState = [[NSUserDefaults standardUserDefaults] objectForKey:@"windowState"];
	if (windowState) {
		NS_DURING 
		{
			self.windowControllers = [NSKeyedUnarchiver unarchiveObjectWithData:windowState];
		}
		NS_HANDLER
		{
			windowState = nil;
		}
		NS_ENDHANDLER
	}
	if (windowState == nil)
		[self newMainWindowWithAccount:nil];
	
	// Listen for window closing notifications
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Save window positions
	int index = 1;
	for (MainWindowController *controller in windowControllers) {
		// Window frame
		NSString *frameName = [NSString stringWithFormat:@"OpenWindow%d", index];
		[controller.window setFrameAutosaveName:frameName];
		[controller.window saveFrameUsingName:frameName];
		index++;
	}
	
	// Save window states for next launch.
	NSData *windowState = [NSKeyedArchiver archivedDataWithRootObject:windowControllers];
	[[NSUserDefaults standardUserDefaults] setObject:windowState forKey:@"windowState"];

	// Save Twitter database.
	[twitter save];
}

#pragma mark Windows

- (IBAction)newMainWindow:(id)sender {
	[self newMainWindowWithAccount:nil];
}

- (void)newMainWindowWithAccount:(TwitterAccount*)account {
	if (account == nil) {
		// Use default account
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *currentAccountScreenName = [defaults objectForKey: @"currentAccount"];
		if (currentAccountScreenName) {
			account = [twitter accountWithScreenName:currentAccountScreenName];
		} else {
			if (twitter.accounts.count > 0) 
				account = [twitter.accounts objectAtIndex: 0];
		}
	}
	
	// Create and show the main window
	MainWindowController *controller = [[[MainWindowController alloc] init] autorelease];
	[controller setAccount:account];
	[controller showWindow:nil];
	[windowControllers addObject:controller];
}

- (void)windowWillClose:(NSNotification*)notification {
	NSWindow *aWindow = [notification object];
	id controller = [aWindow windowController];
	
	if ([controller isKindOfClass: [MainWindowController class]]) {
		[[controller retain] autorelease];
		[windowControllers removeObject: controller];
	} else if (controller == preferences) {
		[[preferences window] orderOut:nil];
	}
}

- (IBAction)showPreferences:(id)sender {
	if (preferences == nil) {
		preferences = [[PreferencesController alloc] initWithTwitter:twitter];
	}
	[preferences showWindow:nil];
}

- (void)addWindowController:(id)controller {
	[windowControllers addObject:controller];
}

#pragma mark Networking

// TODO: add a network activity spinner
- (void) incrementNetworkActionCount {
	networkActionCount++;
	//[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void) decrementNetworkActionCount {
	networkActionCount--;
	if (networkActionCount <= 0) {
		networkActionCount = 0;
		//[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
}

#else
#pragma mark -
#pragma mark iPhone version

@synthesize window, navigationController, twitter;


- (void)awakeFromNib {
	twitter = [[Twitter alloc] init];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	[window addSubview:[navigationController view]];
    [window makeKeyAndVisible];
	return YES;
}


- (void)applicationWillTerminate:(UIApplication *)application {
	[twitter save];
}

- (void) incrementNetworkActionCount {
	networkActionCount++;
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void) decrementNetworkActionCount {
	networkActionCount--;
	if (networkActionCount <= 0) {
		networkActionCount = 0;
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc {
	[window release];
	[navigationController release];
	[twitter release];
	[super dealloc];
}


#endif

@end


