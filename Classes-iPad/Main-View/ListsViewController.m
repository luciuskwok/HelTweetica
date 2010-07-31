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
@synthesize screenName, currentLists, currentSubscriptions;
@synthesize statusMessage, delegate;


- (void) setContentSize {
	// Set the content size
	if ([UIViewController instancesRespondToSelector:@selector(setContentSizeForViewInPopover:)]) {
		int count = currentLists.count + currentSubscriptions.count;
		if (count < 3) count = 3;
		[self setContentSizeForViewInPopover: CGSizeMake(320, 44 * count)];
	}
}

#pragma mark -
#pragma mark Memory management

- (id)initWithAccount:(TwitterAccount*)anAccount {
	if (self = [super initWithNibName:@"Lists" bundle:nil]) {
		account = [anAccount retain];
		[self setContentSize];
	}
	return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
	// Request a fresh list of list subscriptions.
	actions = [[NSMutableArray alloc] init];
	[self loadListsOfUser:screenName];
	self.statusMessage = NSLocalizedString (@"Loading...", @"status message");

    [super viewDidLoad];
	
	// Nav bar visibility. It looks strange to have a popover without a nav bar, and the top of the table gets clipped off.
	[self.navigationController setNavigationBarHidden:NO];
	
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
	[account release];
	[actions release];
	[statusMessage release];
	
	[screenName release];
	[currentLists release];
	[currentSubscriptions release];
	
    [super dealloc];
}

#pragma mark -
#pragma mark TwitterAction

- (void) startTwitterAction:(TwitterAction*)action  {
	[actions addObject: action];
	
	// Set up Twitter action
	action.delegate = self;
	action.consumerToken = account.xAuthToken;
	action.consumerSecret = account.xAuthSecret;
	
	// Start the URL connection
	[action start];
}

- (void) loadListsOfUser:(NSString*)userOrNil {
	// To avoid reloading lists too often, compare the timestamp of a list
	BOOL shouldLoadLists = YES;
	if (currentLists.count > 0) {
		TwitterList *list = [currentLists lastObject];
		if (list.receivedDate && [list.receivedDate timeIntervalSinceNow] > -60)
			shouldLoadLists = NO;
	}
	
	// Load user's own lists.
	if (shouldLoadLists) {
		TwitterLoadListsAction *listsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:NO] autorelease];
		listsAction.completionTarget= self;
		listsAction.completionAction = @selector(didLoadLists:);
		[self startTwitterAction:listsAction];
	}
	
	// To avoid reloading lists too often, compare the timestamp of a list
	BOOL shouldLoadSubscriptions = YES;
	if (currentLists.count > 0) {
		TwitterList *list = [currentSubscriptions lastObject];
		if (list.receivedDate && [list.receivedDate timeIntervalSinceNow] > -60)
			shouldLoadSubscriptions = NO;
	}
	
	// Load lists that user subscribes to.
	if (shouldLoadSubscriptions) {
		TwitterLoadListsAction *subscriptionsAction = [[[TwitterLoadListsAction alloc] initWithUser:userOrNil subscriptions:YES] autorelease];
		subscriptionsAction.completionTarget= self;
		subscriptionsAction.completionAction = @selector(didLoadListSubscriptions:);
		[self startTwitterAction:subscriptionsAction];
	}
}

- (void)didLoadLists:(TwitterLoadListsAction *)action {
	// Keep the old list objects that match new ones because it caches the status updates
	[account synchronizeExisting: currentLists withNew:action.lists];
	[self setContentSize];
	[self.tableView reloadData];
	//[self.tableView flashScrollIndicators];
}

- (void)didLoadListSubscriptions:(TwitterLoadListsAction *)action {
	[account synchronizeExisting: currentSubscriptions withNew:action.lists];
	[self setContentSize];
	[self.tableView reloadData];
	//[self.tableView flashScrollIndicators];
}

#pragma mark -
#pragma mark TwitterAction delegate methods

- (void) twitterActionDidFinishLoading:(TwitterAction*)action {
	// Remove from array of active network connections and update table view.
	[actions removeObject: action];
	
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
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString *name = (screenName) ? [NSString stringWithFormat:@"%@’s", screenName] : @"Your";
	if (section == 0) {
		return [NSString localizedStringWithFormat:@"%@ Lists", name];
	}
	return [NSString localizedStringWithFormat:@"%@ Subscriptions", name];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return currentLists.count ? currentLists.count : 1;
		case 1:
			return currentSubscriptions.count;
	}
   return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
    }
    
    // Configure the cell
	TwitterList *list;
	NSArray *array = (indexPath.section == 0) ? currentLists : currentSubscriptions;
	if (indexPath.row < array.count) {
		list = [array objectAtIndex: indexPath.row];
		cell.textLabel.text = [list.fullName substringFromIndex:1]; // strip off the initial @
		cell.textLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.text = [list.memberCount stringValue];
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

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Only allow selection of rows in the list
	NSArray *array = (indexPath.section == 0) ? currentLists : currentSubscriptions;
	if (indexPath.row >= array.count) return nil;
	return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *array = (indexPath.section == 0) ? currentLists : currentSubscriptions;
	if (indexPath.row < array.count) {
		TwitterList *list = [array objectAtIndex: indexPath.row];

		// Call delegate to tell a list was selected
		if ([delegate respondsToSelector:@selector(lists:didSelectList:)])
			[delegate lists:self didSelectList:list];
	}
}



@end

