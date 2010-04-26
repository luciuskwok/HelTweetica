//
//  TwitterUpdateStatusAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"
#import "TwitterMessage.h"


@interface TwitterUpdateStatusAction : TwitterAction {
}

- (id) initWithText:(NSString*)text inReplyTo:(NSNumber*)replyTo;

@end
