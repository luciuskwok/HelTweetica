//
//  TwitterDeleteAction.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 8/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterAction.h"

@interface TwitterDeleteAction : TwitterAction {
	NSNumber *identifier;
}
@property (nonatomic, retain) NSNumber *identifier;
- (id) initWithMessageIdentifier:(NSNumber*)anIdentifier;
@end
