//
//  LoadSavedSearchesAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TwitterAction.h"
#import "LKJSONParser.h"


@interface TwitterLoadSavedSearchesAction : TwitterAction <LKJSONParserDelegate> {
	NSMutableArray *queries;
	NSString *key;
}
@property (nonatomic, retain) NSMutableArray *queries;
@property (nonatomic, copy) NSString *key;

@end
