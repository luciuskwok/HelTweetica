//
//  TwitterDirectMessageJSONParser.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/26/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterDirectMessageJSONParser.h"
#import "TwitterDirectMessage.h"
#import "TwitterUser.h"


@implementation TwitterDirectMessageJSONParser
@synthesize messages, users, currentMessage, currentUser, receivedTimestamp;

- (id) init {
	if (self = [super init]) {
		messages = [[NSMutableArray alloc] init];
		users = [[NSMutableSet alloc] init];
	}
	return self;
}

- (void) dealloc {
	[messages release];
	[users release];
	
	[currentMessage release];
	[currentUser release];
	
	[receivedTimestamp release];
	[super dealloc];
}

- (void) parseJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
}

#pragma mark Keys

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	NSString *key = parser.keyPath;
	
	if ([key isEqualToString:@"/"]) {
		self.currentMessage = [[[TwitterDirectMessage alloc] init] autorelease];
		currentMessage.receivedDate = receivedTimestamp;
	} else if ([key isEqualToString:@"/recipient/"] || [key isEqualToString:@"/sender/"]) {
		self.currentUser = [[[TwitterUser alloc] init] autorelease];
	}
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	NSString *key = parser.keyPath;
	
	// Statuses
	if ([key isEqualToString:@"/"]) {
		if (currentMessage) {
			// This line depends on the last currentUser to be left over after its dictionary is closed:
			if (currentUser)
				currentUser.updatedDate = currentMessage.createdDate;
			
			// Add object to messages array and set currentMessage to nil so that next object doesn't affect the closed message.
			[messages addObject: currentMessage];
			self.currentMessage = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	} else if ([key isEqualToString:@"/recipient"] || [key isEqualToString:@"/sender"]) {
		// Fill out message fields that are inside the user dictionary
		if (currentUser) {
			// Add to users set.
			[users addObject:currentUser];
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
	
}

#pragma mark Values

- (void) foundValue:(id)value forKeyPath:(NSString*)keyPath {
	if ([keyPath hasPrefix:@"/recipient/"] || [keyPath hasPrefix:@"/sender/"]) {
		[self.currentUser setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/"]) {
		[self.currentMessage setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} 
}

- (void) parser:(LKJSONParser*)parser foundBoolValue:(BOOL)value {
	[self foundValue: [NSNumber numberWithBool:value] forKeyPath:parser.keyPath];
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	[self foundValue: value forKeyPath:parser.keyPath];
}

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	[self foundValue: value forKeyPath:parser.keyPath];
}


@end
