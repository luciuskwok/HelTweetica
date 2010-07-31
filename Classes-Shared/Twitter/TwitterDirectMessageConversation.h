//
//  TwitterDirectMessageConversation.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TwitterDirectMessageConversation : NSObject {
	NSNumber *user;
	NSArray *messages;
}
@property (nonatomic, retain) NSNumber *user;
@property (nonatomic, retain) NSArray *messages;


@end
