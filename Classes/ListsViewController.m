//
//  ListsViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/9/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "ListsViewController.h"
#import "TwitterList.h"
#import "TwitterLoadListsAction.h"


@interface ListsViewController (PrivateMethods)
- (void) loadListsOfUser:(NSString*)userOrNil;
@end

@implementation ListsViewController
@synthesize popover, statusMessage;


- (void) setContentSize {
	// Set the content size
	if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
		TwitterAccount *account = [twitter currentAccount];
		int count = account.lists.count + account.listSubscriptions.count;
		if (count < 3) count = 3;
		[self setContentSizeForViewInPopover: CGSizeMake(320, 44 * count)];
	}
}

#pragma mark -
#pragma mark Memory management

- (id)initWithTwitter:(Twitter*)aTwitter {
	if (self = [super initWithNibName:@"Lists" bundle:nil]) {
		twitter = [aTwitter retain];
		
		[self setContentSize];
		
		// Request a fresh list of list subscriptions.
		actions = [[NSMutableArray alloc] init];
		[self loadListsOfUser:nil];
		self.statusMessage = NSLocalizedString (@"Loading...", @"status message");
	}
	return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Title
	self.navigationItem.title = NSLocalizedString (@"Lists", @"Nav bar");
	
	[self setContentSize];
	[self.tableView reloadData];
	
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidUnload {
}


- (void)dealloc {
	[twitter release];
	[actions release];
	[statusMessage release];
    [super dealloc];
}

#pragma mark -
#pragma mark TwitterAction

- (void) startTwitterAction:(TwitterAction*)action  {
	[actions addObject: action];
	
	// Set up Twitter action
	action.delegate = self;
	action.consumerToken = twitter.currentAccount.xAuthToken;
	action.consumerSecret = twitter.currentAccount.xAuthSecret;
	
	// Start the URL connection
	[action start];
}

- (void) loadListsOfUser:(NSString*)userOrNil {
	// Load user's own lists.
	TwitterLoadListsAction *listsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:NO] autorelease];
	listsAction.completionTarget= self;
	listsAction.completionAction = @selector(didLoadLists:);
	[self startTwitterAction:listsAction];
	
	// Load lists that user subscribes to.
	TwitterLoadListsAction *subscriptionsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:YES] autorelease];
	subscriptionsAction.completionTarget= self;
	subscriptionsAction.completionAction = @selector(didLoadListSubscriptions:);
	[self startTwitterAction:subscriptionsAction];
}

- (void)didLoadLists:(TwitterLoadListsAction *)action {
	twitter.currentAccount.lists = action.lists;
}

- (void)didLoadListSubscriptions:(TwitterLoadListsAction *)action {
	twitter.currentAccount.listSubscriptions = action.lists;
}

#pragma mark -
#pragma mark TwitterAction delegate methods

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	// Remove from array of active network connections and update table view.
	[actions removeObject: action];
	[self setContentSize];
	[self.tableView reloadData];
	
	// Set the default status message after last action is done.
	if (actions.count == 0) {
		self.statusMessage = NSLocalizedString (@"No lists.", @"");
	}		
}

- (void) twitterAction:(TwitterAction*)action didFailWithError:(NSError*)error {
	[actions removeObject: action];
	self.statusMessage = [error localizedDescription];
	[self setContentSize];
	[self.tableView reloadData];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	TwitterAccount *account = [twitter currentAccount];
	int count = account.lists.count + account.listSubscriptions.count;
	if (count == 0)
		return 1;
   return count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
    }
    
    // Configure the cell
	TwitterAccount *account = [twitter currentAccount];
	TwitterList *list;
	if (indexPath.row < account.lists.count) {
		list = [account.lists objectAtIndex: indexPath.row];
		cell.textLabel.text = [list.fullName substringFromIndex:1]; // strip off the initial @
		cell.textLabel.textColor = [UIColor blackColor];
	} else if (indexPath.row < account.lists.count + account.listSubscriptions.count) {
		list = [account.listSubscriptions objectAtIndex: indexPath.row - account.lists.count];
		cell.textLabel.text = [list.fullName substringFromIndex:1]; // strip off the initial @
		cell.textLabel.textColor = [UIColor blackColor];
	} else if (indexPath.row == 0) {
		cell.textLabel.text = self.statusMessage;
		cell.textLabel.textColor = [UIColor grayColor];
	}

    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:aTitle message:aMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	TwitterAccount *account = [twitter currentAccount];
	TwitterList *list = nil;
	if (indexPath.row < account.lists.count) {
		list = [account.lists objectAtIndex: indexPath.row];
	} else if (indexPath.row < account.lists.count + account.listSubscriptions.count) {
		list = [account.listSubscriptions objectAtIndex: indexPath.row - account.lists.count];
	} 
	if (list != nil) {
		[twitter loadTimelineOfList: list];
		if (popover) {
			[popover dismissPopoverAnimated:YES];
			[popover.delegate popoverControllerDidDismissPopover:popover]; // Make sure delegate knows popover has been removed
		}
	}
}



@end

