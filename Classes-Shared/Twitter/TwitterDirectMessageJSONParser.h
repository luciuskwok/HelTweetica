//
//  TwitterDirectMessageJSONParser.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/26/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKJSONParser.h"
@class TwitterDirectMessage;
@class TwitterUser;


@interface TwitterDirectMessageJSONParser : NSObject <LKJSONParserDelegate> {
	NSMutableArray *messages;
	NSMutableSet *users;
	
	TwitterDirectMessage *currentMessage;
	TwitterUser *currentUser;
	
	NSDate *receivedTimestamp;
}

@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) NSMutableSet *users;

@property (nonatomic, retain) TwitterDirectMessage *currentMessage;
@property (nonatomic, retain) TwitterUser *currentUser;

@property (nonatomic, retain) NSDate *receivedTimestamp;

- (void) parseJSONData:(NSData*)jsonData;

@end
