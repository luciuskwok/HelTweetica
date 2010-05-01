//
//  TwitterLoadListsAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterLoadListsAction.h"
#import "TwitterListsJSONParser.h"


@implementation TwitterLoadListsAction
@synthesize lists, currentList, keyPath;


- (id)initWithUser:(NSString*)userOrNil subscriptions:(BOOL)subscriptions {
	self = [super init];
	if (self) {
		NSMutableString *method = [NSMutableString string];
		if (userOrNil) 
			[method appendFormat:@"%@/", userOrNil];
		[method appendString:@"lists"];
		if (subscriptions)
			[method appendString:@"/subscriptions"];
		self.twitterMethod = method;
		self.lists = [NSMutableArray array];
	}
	return self;
}

- (void) dealloc {
	[lists release];
	[currentList release];
	[keyPath release];
	[super dealloc];
}

- (void) start {
	[self startGetRequest];
}

- (void) parseReceivedData:(NSData*)data {
	if (statusCode < 400) {
		LKJSONParser *parser = [[LKJSONParser alloc] initWithData:data];
		parser.delegate = self;
		[parser parse];
		[parser release];
	}
}

#pragma mark -
#pragma mark LKJSONParser delegate methods

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	if (keyPath == nil) {
		self.keyPath = @"/";
	} else {
		self.keyPath = [keyPath stringByAppendingString:@"/"];
	}
	
	if ([keyPath isEqualToString:@"/lists/"]) {
		self.currentList = [[[TwitterList alloc] init] autorelease];
	}
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath substringToIndex: keyPath.length - 1];
	} else {
		self.keyPath = [keyPath stringByDeletingLastPathComponent];
	}
	
	if ([keyPath isEqualToString:@"/lists"]) {
		if (currentList != nil) {
			[lists addObject: currentList];
			self.currentList = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
}

- (void) parserFoundNullValue:(LKJSONParser*)parser {
}

- (void) parser:(LKJSONParser*)parser foundBoolValue:(BOOL)value {
	//NSLog (@"%@ = %d", keyPath, value);
}

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	SInt64 x = 0;
	[[NSScanner scannerWithString:value] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];
	
	if ([keyPath isEqualToString:@"/lists/member_count"]) {
		currentList.memberCount = number;
	} else if ([keyPath isEqualToString:@"/lists/id"]) {
		currentList.identifier = number;
	} 
	
	//NSLog (@"%@ = %@", keyPath, value);
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([keyPath isEqualToString:@"/lists/description"]) {
		currentList.description = value;
	} else if ([keyPath isEqualToString:@"/lists/name"]) {
		currentList.name = value;
	} else if ([keyPath isEqualToString:@"/lists/full_name"]) {
		currentList.fullName = value;
	} else if ([keyPath isEqualToString:@"/lists/slug"]) {
		currentList.slug = value;
	}
	
	//NSLog (@"%@ = %@", keyPath, value);
}

- (void) parser:(LKJSONParser*)parser foundKey:(NSString*)key {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath stringByAppendingPathComponent:key];
	} else {
		NSString *base = [keyPath stringByDeletingLastPathComponent];
		self.keyPath = [base stringByAppendingPathComponent:key];
	}
}

@end
