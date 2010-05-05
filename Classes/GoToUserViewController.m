//
//  GoToUserViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "GoToUserViewController.h"


@implementation GoToUserViewController
@synthesize twitter, users, searchResults, searchController, delegate;


- (id)initWithTwitter:(Twitter*)aTwitter {
	self = [super initWithNibName:@"GoToUser" bundle:nil];
	if (self) {
		self.twitter = aTwitter;
		
		// Sort users by screen name
		NSMutableArray *allUsers = [NSMutableArray arrayWithArray:[aTwitter.users allObjects]];
		NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"screenName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
		[allUsers sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
		self.users = allUsers;
	}
	return self;
}

- (void)dealloc {
	[twitter release];
	[users release];
	[searchResults release];
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
	searchBar.placeholder = NSLocalizedString (@"Screen name or full name", @"search bar placeholder");
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

#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
 	if (aTableView == self.tableView) {
		return 1;
	}
	return 1;
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
 	if (aTableView == self.tableView) {
		return self.users.count;
	}
	return self.searchResults.count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *array = (aTableView == self.tableView) ? self.users : self.searchResults;
	
   	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	}
	
	// Set the label text to the screen name
	if (indexPath.row < array.count) {
		TwitterUser *user = [array objectAtIndex:indexPath.row];
		cell.textLabel.text = user.screenName;
	}
	return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *array = (aTableView == self.tableView) ? self.users : self.searchResults;

	if (indexPath.row < array.count) {
		TwitterUser *user = [array objectAtIndex:indexPath.row];
		if ([delegate respondsToSelector:@selector(showUserPage:)])
			[delegate showUserPage: user.screenName];
	}
}

#pragma mark Search display delegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
	// Filter set by search term
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"screenName CONTAINS[cd] %@ OR fullName CONTAINS[cd] %@", searchString, searchString];
	NSSet *filteredResults = [twitter.users filteredSetUsingPredicate:predicate];
	
	// Sort by screen name case-insensitive
	NSMutableArray *sortedResults = [NSMutableArray arrayWithArray: [filteredResults allObjects]];
	NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"screenName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	[sortedResults sortUsingDescriptors: [NSArray arrayWithObject: descriptor]];
	
	self.searchResults = sortedResults;
	
	return YES;
}

#pragma mark Search bar delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	// Use the entered search term as the user name
	NSString *screenName = searchBar.text;
	if ([delegate respondsToSelector:@selector(showUserPage:)])
		[delegate showUserPage: screenName];
	
}

@end

