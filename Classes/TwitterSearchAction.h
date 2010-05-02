//
//  TwitterSearchAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"


@interface TwitterSearchAction : TwitterAction {
	NSString *query;
	NSArray *messages;
}
@property (nonatomic, copy) NSString *query;
@property (nonatomic, retain) NSArray *messages;

- (id)initWithQuery:(NSString *)aQuery count:(NSString*)count;

@end
