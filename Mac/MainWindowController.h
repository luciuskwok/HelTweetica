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
#import <WebKit/WebKit.h>
#import "AddAccount.h"
#import "LKWebView.h"
#import "TimelineHTMLController.h"


@class Twitter, HelTweeticaAppDelegate;


@interface MainWindowController : NSWindowController <AddAccountDelegate, NSToolbarDelegate> {
	IBOutlet LKWebView *webView;
	IBOutlet NSPopUpButton *accountsPopUp;
	IBOutlet NSSegmentedControl *timelineSegmentedControl;
	IBOutlet NSPopUpButton *usersPopUp;
	IBOutlet NSPopUpButton *listsPopUp;
	IBOutlet NSSearchField *searchField;

	Twitter *twitter;
	TimelineHTMLController *timelineHTMLController;
	
	BOOL webViewHasFinishedLoading;

	HelTweeticaAppDelegate *appDelegate;

	NSWindowController *currentSheet;
}

@property (assign) LKWebView *webView;
@property (assign) NSPopUpButton *accountsPopUp;
@property (assign) NSSegmentedControl *timelineSegmentedControl;
@property (assign) NSPopUpButton *usersPopUp;
@property (assign) NSPopUpButton *listsPopUp;
@property (assign) NSSearchField *searchField;

@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) TimelineHTMLController *timelineHTMLController;

@property (nonatomic, retain) NSWindowController *currentSheet;

- (id)initWithTwitter:(Twitter*)aTwitter;

// Accounts
- (void)reloadAccountsMenu;
- (IBAction)addAccount:(id)sender;
- (IBAction)editAccounts:(id)sender;
- (IBAction)selectAccount:(id)sender;

// Users
- (void)reloadUsersMenu;
- (IBAction)selectUser:(id)sender;

// Lists
- (void)reloadListsMenu;
- (IBAction)selectList:(id)sender;
- (void)loadListsOfUser:(NSString*)userOrNil;

// Actions
- (IBAction)selectTimelineWithSegmentedControl:(id)sender;
- (IBAction)homeTimeline:(id)sender;
- (IBAction)mentions:(id)sender;
- (IBAction)directMessages:(id)sender;
- (IBAction)favorites:(id)sender;
- (IBAction)refresh:(id)sender;

@end
