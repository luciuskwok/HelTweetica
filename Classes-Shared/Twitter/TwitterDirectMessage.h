//
//  TwitterDirectMessage.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/26/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TwitterDirectMessage : NSObject {
	NSNumber *identifier; // primary key
	NSDate *createdDate;
	NSDate *receivedDate;

	NSNumber *senderIdentifier; // key into Users table
	NSString *senderScreenName;
	NSNumber *recipientIdentifier; // key into Users table
	NSString *recipientScreenName;
	NSString *text;
}
@property (nonatomic, retain) NSNumber *identifier; // primary key
@property (nonatomic, retain) NSDate *createdDate;
@property (nonatomic, retain) NSDate *receivedDate;

@property (nonatomic, retain) NSNumber *senderIdentifier; // key into Users table
@property (nonatomic, retain) NSString *senderScreenName;
@property (nonatomic, retain) NSNumber *recipientIdentifier; // key into Users table
@property (nonatomic, retain) NSString *recipientScreenName;
@property (nonatomic, retain) NSString *text;

+ (NSArray *)databaseKeys;

- (id)initWithDictionary:(NSDictionary *)d;
- (id)databaseValueForKey:(NSString *)key;
- (void) setValue:(id)value forTwitterKey:(NSString*)key;

// HTML
- (NSDictionary *)htmlSubstitutions;

@end
