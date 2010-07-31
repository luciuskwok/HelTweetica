//
//  TwitterDirectMessageTimeline.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterTimeline.h"


@interface TwitterDirectMessageTimeline : TwitterTimeline {
	NSNumber *accountIdentifier; // Used to determine whether a direct message was sent or received.
}
@property (nonatomic, retain) NSNumber *accountIdentifier;

- (void)addMessages:(NSArray *)messages sent:(BOOL)sent;

@end
