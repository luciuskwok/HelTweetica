    //
//  TimelineViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/3/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TimelineViewController.h"
#import "LKWebView.h"
#import "HelTweeticaAppDelegate.h"


@implementation TimelineViewController
@synthesize webView, twitter, actions, defaultCount;
@synthesize currentPopover, currentActionSheet, currentAlert;

// Initializer for programmatically creating this
- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
	self = [super initWithNibName:nibName bundle:nibBundle];
	if (self) {
		// Use Twitter instance from app delegate
		HelTweeticaAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
		self.twitter = appDelegate.twitter;
		
		// String to pass in the count, per_page, and rpp parameters.
		self.defaultCount = @"100";
		
		// List of currently active network connections
		self.actions = [NSMutableArray array];
	}
	return self;
}

// Initializer for loading from nib
- (void) awakeFromNib {
	// Use Twitter instance from app delegate
	HelTweeticaAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	self.twitter = appDelegate.twitter;
	
	// String to pass in the count, per_page, and rpp parameters.
	self.defaultCount = @"100";
	
	// List of currently active network connections
	self.actions = [NSMutableArray array];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
	self.webView = nil;
}

- (void)dealloc {
	[webView release];
	[twitter release];
	[actions release];
	[defaultCount release];
    [super dealloc];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark Popovers

- (BOOL)closeAllPopovers {
	// Returns YES if any popovers were visible and closed.
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		// Close any action sheets
		if (currentActionSheet != nil) {
			[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
			self.currentActionSheet = nil;
			return YES;
		}
		
		// If a popover is already shown, close it. 
		if (currentPopover != nil) {
			[currentPopover dismissPopoverAnimated:YES];
			self.currentPopover = nil;
			return YES;
		}
	}
	return NO;
}

- (void)popoverControllerDidDismissPopover: (UIPopoverController *) popoverController {
	self.currentPopover = nil;
}

- (UIPopoverController*) presentPopoverFromItem:(UIBarButtonItem*)item viewController:(UIViewController*)vc {
	// Present popover
	UIPopoverController *popover = [[[NSClassFromString(@"UIPopoverController") alloc] initWithContentViewController:vc] autorelease];
	popover.delegate = self;
	[popover presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	self.currentPopover = popover;
	return popover;
}	

- (void) presentContent: (UIViewController*) contentViewController inNavControllerInPopoverFromItem: (UIBarButtonItem*) item {
	UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController: contentViewController] autorelease];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[self presentPopoverFromItem:item viewController:navController];
		
		/* The only reason that the content view controller has a reference to the popover is so that it can close it. 
			An alternative is to have the delegate methods include one to close the popover.
			Chockenberry's solution is to have a global variable or singleton which manages the popover.
		*/
		
	} else { // iPhone
		navController.navigationBar.barStyle = UIBarStyleBlack;
		[self presentModalViewController:navController animated:YES];
	}
}


@end
