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



@implementation ListsViewController
@synthesize popover;

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
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(listsDidChange:) name:@"listsDidChange" object:nil];
		[nc addObserver:self selector:@selector(listSubscriptionsDidChange:) name:@"listSubscriptionsDidChange" object:nil];
		
		// TODO: fix obsolete network handling. 
		// [nc addObserver:self selector:@selector(networkError:) name:@"twitterNetworkError" object:nil];
		
		// Title
		self.navigationItem.title = NSLocalizedString (@"Lists", @"Nav bar");

		// Request a fresh list of list subscriptions.
		loading = YES;
		[twitter loadListsOfUser:nil];
	}
	return self;
}

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
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[twitter release];
	[nc removeObserver:self];
    [super dealloc];
}

#pragma mark -

- (void) listsDidChange: (NSNotification*) aNotification {
	// Chain load subscriptions
	[twitter loadListSubscriptionsOfUser:nil];
}

- (void) listSubscriptionsDidChange: (NSNotification*) aNotification {
	loading = NO;
	[self setContentSize];
	[self.tableView reloadData];
}

- (void) networkError: (NSNotification*) aNotification {
	loading = NO;
	[self.tableView reloadData];
}


#pragma mark -
#pragma mark View lifecycle

/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
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
/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	TwitterAccount *account = [twitter currentAccount];
	int count = account.lists.count + account.listSubscriptions.count;
	if (count == 0) {
		return 1;
	}
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
	} else {
		if (loading) 
			cell.textLabel.text = NSLocalizedString (@"Loading...", @"");
		else
			cell.textLabel.text = NSLocalizedString (@"No lists.", @"");
		cell.textLabel.textColor = [UIColor grayColor];
	}
	
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


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

