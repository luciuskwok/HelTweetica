//
//  TwitterSearchJSONParser.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKJSONParser.h"
@class TwitterMessage;


@interface TwitterSearchJSONParser : NSObject <LKJSONParserDelegate> {
	NSMutableArray *messages;
	TwitterMessage *currentMessage;
	NSString *keyPath;
	NSDate *receivedTimestamp;
}

@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) TwitterMessage *currentMessage;
@property (nonatomic, retain) NSString *keyPath;
@property (nonatomic, retain) NSDate *receivedTimestamp;

- (NSArray*) messagesWithJSONData:(NSData*)jsonData;

@end
