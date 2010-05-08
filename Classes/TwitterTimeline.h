//
//  TwitterTimeline.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/7/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TwitterTimeline : NSObject {
	NSMutableArray *messages;
	NSMutableArray *gaps;
}
@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) NSMutableArray *gaps;

@end
