//
//  TwitterSavedSearch.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TwitterSavedSearch : NSObject {
	NSString *query;
	NSNumber *identifier;
	NSDate *receivedDate;
}
@property (nonatomic, retain) NSString *query;
@property (nonatomic, retain) NSNumber *identifier;
@property (nonatomic, retain) NSDate *receivedDate;

@end
