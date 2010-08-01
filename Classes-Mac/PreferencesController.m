//
//  PreferencesController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/26/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PreferencesController.h"
#import "AddAccount.h"


// Constants
NSString *kTableRowDragType = @"tableRowIndexSet";


@implementation PreferencesController
@synthesize tableView, twitter, currentSheet;


- (id)initWithTwitter:(Twitter*)aTwitter {
	self = [super initWithWindowNibName:@"Preferences"];
	if (self) {
		self.twitter = aTwitter;

		// Image to indicate that account is not logged in
		alertImage = [[NSImage imageNamed:@"alert"] retain];
		
		// Listen for changes to Twitter state data
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(accountsDidChange:) name:@"accountsDidChange" object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[twitter release];
	[alertImage release];
	[currentSheet release];
	[super dealloc];
}

- (void)windowDidLoad { 
	// Set up table view for dragging
	[tableView registerForDraggedTypes:[NSArray arrayWithObject:kTableRowDragType]];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	self.currentSheet = nil;
}

- (void)accountsDidChange:(NSNotification*)notification {
	[tableView reloadData];
}

- (void)loginFailedWithAccount:(TwitterAccount*)anAccount {
	[self showAlertWithTitle:@"Login failed." message:@"The username or password was not correct."];
}

#pragma mark Actions

- (IBAction)add:(id)sender {
	AddAccount* sheet = [[[AddAccount alloc] initWithTwitter:twitter] autorelease];
	sheet.delegate = self;
	[sheet askInWindow: [self window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)];
	self.currentSheet = sheet;
}

- (IBAction)remove:(id)sender {
	NSIndexSet *selection = [tableView selectedRowIndexes];
	NSMutableArray *unselectedAccounts = [NSMutableArray array];
	int index;
	
	for (index = 0; index < twitter.accounts.count; index++) {
		TwitterAccount *account = [twitter.accounts objectAtIndex:index];
		if ([selection containsIndex:index] == NO) {
			[unselectedAccounts addObject: account];
		} else {
			// Delete caches in database to free up space & allow reset by deleting and re-adding account.
			[account deleteCaches];
		}
	}
	
	[twitter setAccounts:unselectedAccounts];
	[tableView deselectAll:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"accountsDidChange" object:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	BOOL result;
	if (menuItem.action == @selector(remove:)) {
		result = ([tableView numberOfSelectedRows] > 0);
	} else {
		result = [super validateMenuItem:menuItem];
	}
	return result;
}

#pragma mark Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return twitter.accounts.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	id result = nil;
	if (rowIndex < twitter.accounts.count) {
		TwitterAccount *account = [twitter.accounts objectAtIndex:rowIndex];
		if ([aTableColumn.identifier isEqual:@"screenName"]) {
			result = account.screenName;
		} else if ([aTableColumn.identifier isEqual:@"status"]) {
			if (account.xAuthToken == nil) 
				result = alertImage;
		}
		
	}
	return result;
}

#pragma mark Table view drag and drop

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint {
	int row = [rowIndexes firstIndex];
	return (row >= 0) && (row < twitter.accounts.count);
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
	// Copy the row numbers to the pasteboard.
	[pboard declareTypes:[NSArray arrayWithObject:kTableRowDragType] owner:self];
	[pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:kTableRowDragType];
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	if (row < 0) row = 0;
	[aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
	return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op {
	NSData* rowData = [[info draggingPasteboard] dataForType:kTableRowDragType];
	NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
	int dragRow = [rowIndexes firstIndex];
	
	if (row > dragRow) row--;
	
	id item = [[twitter.accounts objectAtIndex:dragRow] retain];
	[twitter.accounts removeObjectAtIndex:dragRow];
	[twitter.accounts insertObject:item atIndex:row];
	[item release];
	[aTableView reloadData];
	return YES;
}

#pragma mark Alert

- (void) showAlertWithTitle:(NSString*)aTitle message:(NSString*)aMessage {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:aTitle];
	[alert setInformativeText:aMessage];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

-  (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {	self.currentSheet = nil;
}

#pragma mark AddAccount delegate

- (void)didLoginToAccount:(TwitterAccount *)anAccount {
	[self.tableView reloadData];
}

@end
