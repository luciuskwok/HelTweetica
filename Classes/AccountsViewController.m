//
//  AccountsViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/8/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "AccountsViewController.h"
#import "LoginViewController.h"


@interface AccountsViewController (PrivateMethods)
- (void) setContentSize;
@end


@implementation AccountsViewController
@synthesize popover;

- (id)initWithTwitter:(Twitter*)aTwitter {
	if (self = [super initWithNibName:@"Accounts" bundle:nil]) {
		twitter= [aTwitter retain];
		
		if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
			NSString *closeTitle = NSLocalizedString (@"Close", @"");
			UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:closeTitle style:UIBarButtonSystemItemDone target:self action:@selector(close:)];
			self.navigationItem.leftBarButtonItem = closeButton;
			[closeButton release];
		}
		[self setContentSize];
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(twitterAccountsDidChange:) name:@"twitterAccountsDidChange" object:nil];
		[nc addObserver:self selector:@selector(twitterAccountsDidChange:) name:@"currentAccountDidChange" object:nil];
	}
	return self;
}

- (void) setContentSize {
	// Set the content size
	if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
		int count = twitter.accounts.count;
		if (count < 3) count = 3;
		[self setContentSizeForViewInPopover: CGSizeMake(320, 44 * count)];
	}
}

- (IBAction) add:(id)sender {
 	LoginViewController *c = [[[LoginViewController alloc] initWithTwitter:twitter] autorelease];
	[self.navigationController pushViewController: c animated: YES];
}

- (IBAction) close:(id)sender {
	if (popover != nil) {
		[popover dismissPopoverAnimated:YES];
		// Make sure delegate knows popover has been removed
		[popover.delegate popoverControllerDidDismissPopover:popover];
	} else {
		[self dismissModalViewControllerAnimated:YES];
	}
}

- (void) reload {
	[self setContentSize];
	[[self tableView] reloadData];
}

- (void) twitterAccountsDidChange:(NSNotification*)aNotification {
	//[self performSelectorOnMainThread:@selector(reload) withObject:nil waitUntilDone:NO];
	[self reload];
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

	// Title
	[self.navigationItem setTitle:@"Twitter"];

    // Edit button.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	// Add button
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add:)];
	self.navigationItem.leftBarButtonItem = addButton;
	[addButton release];
}

- (void) viewWillAppear:(BOOL)animated {
	[self setContentSize]; 
	[super viewWillAppear:animated];
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
     return YES;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return twitter.accounts.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell
	NSArray *accounts = [twitter accounts];
	int row = indexPath.row;
	if ((0 <= row) && (row < accounts.count)) {
		TwitterAccount *account = [accounts objectAtIndex: indexPath.row];
		BOOL loggedIn = (account.xAuthToken != nil);
		cell.textLabel.text = account.screenName;
		cell.textLabel.textColor = loggedIn ? [UIColor blackColor] : [UIColor grayColor];
	}
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
		[twitter.accounts removeObjectAtIndex: indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
	[twitter moveAccountAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 	NSArray *accounts = [twitter accounts];
	int row = indexPath.row;
	if ((0 <= row) && (row < accounts.count)) {
		TwitterAccount *account = [accounts objectAtIndex: row];
		if (account.xAuthToken != nil) {
			// Make this account the current one.
			[twitter setCurrentAccount: account];
			[twitter saveAccounts];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"currentAccountDidChange" object:self];
			if (popover == nil) 
				[self dismissModalViewControllerAnimated:YES];
		} else {
			// if xauth token isn't there, maybe because login failed, allow user to re-login
			LoginViewController *c = [[[LoginViewController alloc] initWithTwitter:twitter] autorelease];
			c.screenName = account.screenName;
			[self.navigationController pushViewController: c animated: YES];
		}
	}
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[twitter release];
	[super dealloc];
}


@end

