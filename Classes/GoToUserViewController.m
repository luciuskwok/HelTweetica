//
//  GoToUserViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "GoToUserViewController.h"


@implementation GoToUserViewController
@synthesize twitter, users, searchController, delegate;


- (id)initWithTwitter:(Twitter*)aTwitter {
	self = [super initWithNibName:@"GoToUser" bundle:nil];
	if (self) {
		self.twitter = aTwitter;
		
		// Sort users by screen name
		NSMutableArray *allUsers = [NSMutableArray arrayWithArray:[aTwitter.users allObjects]];
		NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"screenName" ascending:YES] autorelease];
		[allUsers sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
		self.users = allUsers;
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	[users release];
	[searchController release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Set table header view
	CGRect frame = self.view.bounds;
	frame.size.height = 44;
	UISearchBar *searchBar = [[[UISearchBar alloc] initWithFrame:frame] autorelease];
	searchBar.delegate = self;
	searchBar.tintColor = [UIColor blackColor];
	searchBar.placeholder = NSLocalizedString (@"Screen name", @"search bar placeholder");
	self.tableView.tableHeaderView = searchBar;
	
	// Title
	self.navigationItem.title = NSLocalizedString (@"Go to User", @"Nav bar");
	
	// Display an Edit button in the navigation bar for this view controller.
    //self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	// Search display controller
	self.searchController = [[[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self] autorelease];
	searchController.delegate = self;
	searchController.searchResultsDataSource = self;
	searchController.searchResultsDelegate = self;
	
}

- (void)viewDidUnload {
	[super viewDidUnload];
	self.searchController = nil;
}

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


#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
 	if (aTableView == self.tableView) {
		return 1;
	}
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
 	if (aTableView == self.tableView) {
		return self.users.count;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   	if (aTableView == self.tableView) {
		static NSString *CellIdentifier = @"Cell";
		UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		}
		
		// Set the label text to the screen name
		if (indexPath.row < self.users.count) {
			TwitterUser *user = [self.users objectAtIndex:indexPath.row];
			cell.textLabel.text = user.screenName;
		}
		return cell;
    }
	
	// Search display controller
    return nil;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (aTableView == self.tableView) {
		if (indexPath.row < self.users.count) {
			TwitterUser *user = [self.users objectAtIndex:indexPath.row];
			if ([delegate respondsToSelector:@selector(showUserPage:)])
				[delegate showUserPage: user.screenName];
		}
	}
}



@end

