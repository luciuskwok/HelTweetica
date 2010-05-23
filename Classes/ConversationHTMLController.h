//
//  ConversationHTMLController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TimelineHTMLController.h"


@interface ConversationHTMLController : TimelineHTMLController {
	NSNumber *selectedMessageIdentifier;
	BOOL loadingComplete;
	BOOL messageNotFound;
	BOOL protectedUser;
	NSString *highlightedTweetRowTemplate;
}
@property (nonatomic, retain) NSNumber *selectedMessageIdentifier;

- (id)initWithMessageIdentifier:(NSNumber*)anIdentifier;
- (void)loadMessage:(NSNumber*)messageIdentifier;
- (void)loadInReplyToMessage:(TwitterMessage*)message;

@end
