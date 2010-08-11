//
//  TwitterDirectMessageConversation.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TwitterDirectMessageConversation : NSObject {
	NSNumber *userIdentifier;
	NSMutableArray *messages;
}
@property (nonatomic, retain) NSNumber *userIdentifier;
@property (nonatomic, retain) NSMutableArray *messages;

- (id)initWithUserIdentifier:(NSNumber *)identifier;

@end
