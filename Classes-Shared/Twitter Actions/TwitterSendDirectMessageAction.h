//
//  TwitterSendDirectMessageAction.h
//  HelTweetica-iPad
//
//  Created by Brian Papa on 8/31/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"
#import "LKJSONParser.h"

@protocol LKJSONParserDelegate;

@interface TwitterSendDirectMessageAction : TwitterAction <LKJSONParserDelegate> {
	NSString *screenNameTo;
}

@property (nonatomic,copy) NSString *screenNameTo;

- (id)initWithText:(NSString*)text to:(NSString*)screenName;

@end
