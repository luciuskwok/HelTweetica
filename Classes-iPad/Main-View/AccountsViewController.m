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


@implementation AccountsViewController
@synthesize delegate;

- (void) setContentSize {
	// Set the size of the popover
	if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
		int count = twitter.accounts.count;
		if (count < 3) count = 3;
		[self setContentSizeForViewInPopover: CGSizeMake(320, 44 * count)];
	}
}

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
	}
	return self;
}

- (IBAction) add:(id)sender {
 	LoginViewController *c = [[[LoginViewController alloc] initWithTwitter:twitter] autorelease];
	c.delegate = self;
	[self.navigationController pushViewController: c animated: YES];
}

- (IBAction) close:(id)sender {
	// This is only called on the iPhone.
	[self dismissModalViewControllerAnimated:YES];
}

- (void) reload {
	[self setContentSize];
	[[self tableView] reloadData];
}

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
		TwitterAccount *account = [twitter.accounts objectAtIndex:indexPath.row];
		[account deleteCaches];
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

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 	NSArray *accounts = [twitter accounts];
	int row = indexPath.row;
	if ((0 <= row) && (row < accounts.count)) {
		TwitterAccount *account = [accounts objectAtIndex: row];
		if (account.xAuthToken != nil) {
			// Call delegate to tell an account was selected
			if ([delegate respondsToSelector:@selector(didSelectAccount:)])
				[delegate didSelectAccount:account];
		} else {
			// if xauth token isn't there, maybe because login failed, allow user to re-login
			LoginViewController *c = [[[LoginViewController alloc] initWithTwitter:twitter] autorelease];
			c.delegate = self;
			c.screenName = account.screenName;
			[self.navigationController pushViewController: c animated: YES];
		}
	}
}

#pragma mark Login view controller delegate

- (void) loginWithScreenName:(NSString*)screenName password:(NSString*)password {
	// Create an account for this username if one doesn't already exist
	TwitterAccount *account = [twitter accountWithScreenName: screenName];
	if (account == nil) {
		account = [[[TwitterAccount alloc] init] autorelease];
		account.screenName = screenName;
		[twitter.accounts addObject: account];
		[self reload];
	}
	
	// Create and send the login action.
	TwitterLoginAction *action = [[[TwitterLoginAction alloc] initWithUsername:screenName password:password] autorelease];
	action.completionTarget= self;
	action.completionAction = @selector(didLogin:);

	// Set up Twitter action
	action.delegate = self;
	
	// Start the URL connection
	[action start];
}

- (void) didLogin:(TwitterLoginAction *)action {
	if (action.token) {
		// Save the login information for the account.
		TwitterAccount *account = [twitter accountWithScreenName: action.username];
		account.xAuthToken = action.token;
		account.xAuthSecret = action.secret;
		account.screenName = action.username; // To make sure the uppercase/lowercase letters are correct.
		account.identifier = action.identifier;
		
		// Set database connection.
		[account setDatabase:twitter.database];

		// Tell delegate we're done
		if ([delegate respondsToSelector:@selector(didSelectAccount:)])
			[delegate didSelectAccount:account];
	} else {
		// Login was not successful, so report the error.
		NSString *title = NSLocalizedString (@"Login failed.", @"alert");
		NSString *message = NSLocalizedString (@"Username or password was incorrect.", @"alert");
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[alert show];
	}
}


#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
}

- (void)dealloc {
	[twitter release];
	[super dealloc];
}

@end

