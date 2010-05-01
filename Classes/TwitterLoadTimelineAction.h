//
//  TwitterLoadTimelineAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"


@interface TwitterLoadTimelineAction : TwitterAction {
	NSArray *messages;
}
@property (nonatomic, retain) NSArray *messages;

- (id)initWithTwitterMethod:(NSString*)method sinceIdentifier:(NSNumber*)sinceId maxIdentifier:(NSNumber*)maxId count:(NSNumber*)count page:(NSNumber*)page ;

@end
