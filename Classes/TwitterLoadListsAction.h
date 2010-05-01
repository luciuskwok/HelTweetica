//
//  TwitterLoadListsAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"
#import "TwitterList.h"
#import "LKJSONParser.h"


@interface TwitterLoadListsAction : TwitterAction <LKJSONParserDelegate> {
	NSMutableArray *lists;
	TwitterList *currentList;
	NSString *keyPath;
}
@property (nonatomic, retain) NSMutableArray *lists;
@property (nonatomic, retain) TwitterList *currentList;
@property (nonatomic, retain) NSString *keyPath;

- (id)initWithUser:(NSString*)userOrNil subscriptions:(BOOL)subscriptions;

@end
