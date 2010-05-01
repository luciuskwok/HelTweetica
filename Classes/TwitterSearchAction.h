//
//  TwitterSearchAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"
#import "TwitterMessage.h"
#import "LKJSONParser.h"


@interface TwitterSearchAction : TwitterAction <LKJSONParserDelegate> {
	NSString *query;
	NSMutableArray *messages;
	TwitterMessage *currentMessage;
	NSString *keyPath;
	NSDate *receivedTimestamp;
}
@property (nonatomic, copy) NSString *query;
@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) TwitterMessage *currentMessage;
@property (nonatomic, retain) NSString *keyPath;
@property (nonatomic, retain) NSDate *receivedTimestamp;

- (id)initWithQuery:(NSString *)aQuery;

@end
