//
//  Compose.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@protocol ComposeDelegate;

@interface Compose : NSWindowController {
	IBOutlet NSTextField *textField;
	IBOutlet NSTextField *charactersRemaining;
	IBOutlet NSSegmentedControl *retweetStyleControl;
	IBOutlet NSTextField *retweetStyleLabel;
	IBOutlet NSButton *tweetButton;
	
	NSString *messageContent;
	NSNumber *inReplyTo;
	NSString *originalRetweetContent;
	BOOL newStyleRetweet;
	
	id <ComposeDelegate> delegate;
}

@property (assign) NSTextField *textField;
@property (assign) NSTextField *charactersRemaining;
@property (assign) NSSegmentedControl *retweetStyleControl;
@property (assign) NSTextField *retweetStyleLabel;
@property (assign) NSButton *tweetButton;

@property (nonatomic, retain) NSString *messageContent;
@property (nonatomic, retain) NSNumber *inReplyTo;
@property (nonatomic, retain) NSString *originalRetweetContent;
@property (assign) BOOL newStyleRetweet;

@property (assign) id delegate;

// UI updating
- (void)updateCharacterCount;

// Sheet
- (void) askInWindow:(NSWindow *)aWindow modalDelegate:(id)del didEndSelector:(SEL)sel;

// Actions
- (IBAction)tweet:(id)sender;
- (IBAction)close:(id)sender;
- (IBAction)selectRetweetStyle:(id)sender;

// Defaults
- (void)loadFromUserDefaults;
- (void)saveToUserDefaults;

@end

@protocol ComposeDelegate
- (void) compose:(Compose*)aCompose didSendMessage:(NSString*)text inReplyTo:(NSNumber*)inReplyTo;
- (void) compose:(Compose*)aCompose didRetweetMessage:(NSNumber*)identifier;
@end
