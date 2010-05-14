//
//  TwitterTimeline.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/7/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterTimeline.h"
#import "TwitterLoadTimelineAction.h"


@implementation TwitterTimeline
@synthesize messages, gaps, loadAction;

- (id)init {
	self = [super init];
	if (self) {
		self.messages = [NSMutableArray array];
		self.gaps = [NSMutableArray array];
	}
	return self;
}

- (void)dealloc {
	[messages release];
	[gaps release];
	[loadAction release];
	[super dealloc];
}

#pragma mark NSCoding

- (NSMutableArray*) mutableArrayForKey:(NSString *)key coder:(NSCoder *)decoder {
	NSData *data = [decoder decodeObjectForKey:key];
	NSMutableArray *array;
	if (data && [data isKindOfClass:[NSData class]]) {
		array = [NSMutableArray arrayWithArray: [NSKeyedUnarchiver unarchiveObjectWithData:data]];
	} else {
		array = [NSMutableArray array];
	}
	return array;
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.messages = [self mutableArrayForKey:@"messages" coder:decoder];
		self.gaps = [self mutableArrayForKey:@"gaps" coder:decoder];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:messages] forKey: @"messages"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:gaps] forKey: @"gaps"];
}

#pragma mark Synchronize

- (void)removeMessageWithIdentifier:(NSNumber*)anIdentifier {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", anIdentifier];
	NSMutableArray *filteredArray = [NSMutableArray arrayWithArray: self.messages];
	[filteredArray filterUsingPredicate:predicate];
	[self.messages removeObjectsInArray:filteredArray];
}

- (void)limitTimelineLength:(int)maxLength {
	// Limit the length of the timeline
	if (messages.count > maxLength) {
		NSRange removalRange = NSMakeRange(maxLength, messages.count - maxLength);
		[messages removeObjectsInRange:removalRange];
	}
}	


@end
