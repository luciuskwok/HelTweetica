//
//  GoToUserViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "GoToUserViewController.h"


@implementation GoToUserViewController
@synthesize twitter, users, searchResults, searchController, delegate;


- (id)initWithTwitter:(Twitter*)aTwitter {
	self = [super initWithNibName:@"GoToUser" bundle:nil];
	if (self) {
		self.twitter = aTwitter;
		self.users = [aTwitter allUsers];
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
	//searchBar.tintColor = [UIColor blackColor];
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
	
	// Set the keyboard focus on the search bar
	//[searchBar becomeFirstResponder]; // This isn't working.
}

- (void)viewDidUnload {
	[super viewDidUnload];
	self.searchController = nil;
}

#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
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
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
	}
	
	// Set the label text to the screen name
	if (indexPath.row < array.count) {
		TwitterUser *user = [array objectAtIndex:indexPath.row];
		cell.textLabel.text = user.screenName;
		cell.detailTextLabel.text = user.fullName ? user.fullName : @"";
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
	self.searchResults = [twitter usersWithName:searchString];
	return YES;
}

#pragma mark Search bar delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	// Use the entered search term as the user name. Remove whitespace from screenName.
	NSString *screenName = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([delegate respondsToSelector:@selector(showUserPage:)])
		[delegate showUserPage: screenName];
	
}

@end

