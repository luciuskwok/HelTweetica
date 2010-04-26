//
//  TwitterFavoriteAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"
#import "TwitterMessage.h"


@interface TwitterFavoriteAction : TwitterAction {
	TwitterMessage *message;
	BOOL destroy;
}
@property (nonatomic, retain) TwitterMessage *message;

- (id) initWithMessage:(TwitterMessage*)aMessage destroy:(BOOL)flag;

@end
