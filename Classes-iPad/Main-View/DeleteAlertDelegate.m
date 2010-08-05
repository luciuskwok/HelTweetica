//
//  DeleteAlertDelegate.m
//  HelTweetica-iPad
//
//  Created by Lucius Kwok on 8/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "DeleteAlertDelegate.h"


@implementation DeleteAlertDelegate
@synthesize identifier, htmlController, delegate;

- (void)dealloc {
	[identifier release];
	[htmlController release];
	[super dealloc];
}

- (UIAlertView *)showAlert {
	NSString *title = NSLocalizedString(@"Delete Tweet?", @"title");
	NSString *message = NSLocalizedString(@"This tweet will be deleted permanently and cannot be undone.", @"message");
	NSString *deleteButton = NSLocalizedString(@"Delete", @"button");
	NSString *cancelButton = NSLocalizedString(@"Cancel", @"button");
	
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:cancelButton otherButtonTitles:deleteButton, nil] autorelease];
	[alert show];
	return alert;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex != alertView.cancelButtonIndex) { // Delete
		[htmlController deleteStatusUpdate:identifier];
	}
	[delegate alertView:alertView didDismissWithButtonIndex:buttonIndex];
}


@end
