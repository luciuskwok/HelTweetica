//
//  MainWindowController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/22/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Cocoa/Cocoa.h>
#import "AddAccount.h"
#import "TimelineHTMLController.h"
#import "LKWebView.h"


@class Twitter, HelTweeticaAppDelegate;


@interface MainWindowController : NSWindowController <AddAccountDelegate> {
	IBOutlet LKWebView *webView;
	IBOutlet NSPopUpButton *usersPopUp;
	IBOutlet NSSegmentedControl *timelineSegmentedControl;
	IBOutlet NSPopUpButton *listsPopUp;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSMenu *searchMenu;

	HelTweeticaAppDelegate *appDelegate;
	TimelineHTMLController *htmlController;
	NSMutableArray *lists;
	NSMutableArray *subscriptions;
	
	NSWindowController *currentSheet;
}

@property (assign) LKWebView *webView;
@property (assign) NSPopUpButton *usersPopUp;
@property (assign) NSSegmentedControl *timelineSegmentedControl;
@property (assign) NSPopUpButton *listsPopUp;
@property (assign) NSSearchField *searchField;
@property (assign) NSMenu *searchMenu;

@property (nonatomic, retain) TimelineHTMLController *htmlController;
@property (nonatomic, retain) NSMutableArray *lists;
@property (nonatomic, retain) NSMutableArray *subscriptions;

@property (nonatomic, retain) NSWindowController *currentSheet;

- (id)initWithTwitter:(Twitter*)aTwitter account:(TwitterAccount*)account;

// Timelines
- (IBAction)selectTimelineWithSegmentedControl:(id)sender;
- (IBAction)homeTimeline:(id)sender;
- (IBAction)mentions:(id)sender;
- (IBAction)directMessages:(id)sender;
- (IBAction)favorites:(id)sender;
- (IBAction)refresh:(id)sender;

// Users
- (void)reloadUsersMenu;
- (IBAction)goToUser:(id)sender;
- (IBAction)myProfile:(id)sender;
- (IBAction)addAccount:(id)sender;
- (IBAction)editAccounts:(id)sender;
- (IBAction)selectAccount:(id)sender;

// Lists
- (void)reloadListsMenu;
- (IBAction)selectList:(id)sender;
- (void)loadListsOfUser:(NSString*)userOrNil;

// Search
- (void)reloadSearchMenu;
- (IBAction)search:(id)sender;
- (void) searchForQuery:(NSString*)query;
- (void)loadSavedSearches;

// Web actions
- (void) showUserPage:(NSString*)screenName;


@end
