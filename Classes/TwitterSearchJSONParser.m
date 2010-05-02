//
//  TwitterSearchJSONParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/2/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterSearchJSONParser.h"
#import "TwitterMessage.h"


@implementation TwitterSearchJSONParser
@synthesize messages, currentMessage, keyPath, receivedTimestamp;

- (id) init {
	if (self = [super init]) {
		messages = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	[messages release];
	[currentMessage release];
	[keyPath release];
	[receivedTimestamp release];
	[super dealloc];
}

- (NSArray*) messagesWithJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
	return [[messages retain] autorelease];
}

#pragma mark -
// LKJSONParser delegate methods

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	if (keyPath == nil) {
		self.keyPath = @"/";
	} else {
		if ([keyPath hasSuffix:@"/"] == NO)
			self.keyPath = [keyPath stringByAppendingString:@"/"];
	}
	
	if ([keyPath isEqualToString:@"/results/"]) {
		self.currentMessage = [[[TwitterMessage alloc] init] autorelease];
		currentMessage.receivedDate = receivedTimestamp;
	}
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath substringToIndex: keyPath.length - 1];
	} else {
		self.keyPath = [keyPath stringByDeletingLastPathComponent];
	}
	
	if ([keyPath isEqualToString:@"/results"]) {
		if (currentMessage != nil) {
			[messages addObject: currentMessage];
			self.currentMessage = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
}

- (void) parser:(LKJSONParser*)parser foundKey:(NSString*)key {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath stringByAppendingPathComponent:key];
	} else {
		NSString *base = [keyPath stringByDeletingLastPathComponent];
		self.keyPath = [base stringByAppendingPathComponent:key];
	}
}

// currentMessage.favorite needs an indeterminite state because search API doesn't return this info.

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	SInt64 x = 0;
	[[NSScanner scannerWithString:value] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];
	
	if ([keyPath isEqualToString:@"/results/id"]) {
		currentMessage.identifier = number;
	} else if ([keyPath isEqualToString:@"/results/from_user_id"]) {
		//currentMessage.inReplyToStatusIdentifier = number; // Search uses different user ID numbers than Twitter's main feed, so ignore them for now.
	} else if ([keyPath isEqualToString:@"/results/to_user_id"]) {
		//currentMessage.inReplyToUserIdentifier = number;
	}
	
}

- (NSDate*) dateWithSearchString: (NSString*) string {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZ"]; // Mon, 25 Jan 2010 00:46:47 +0000 
	NSDate *result = [formatter dateFromString:string];
	[formatter release];
	return result;
}

- (NSString *)stringReplacingAmpersandEscapes:(NSString *)string {
	NSMutableString *result = [NSMutableString stringWithString:string];
	[result replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([keyPath isEqualToString:@"/results/to_user"]) {
		currentMessage.inReplyToScreenName = value;
	} else if ([keyPath isEqualToString:@"/results/source"]) {
		currentMessage.source = [self stringReplacingAmpersandEscapes:value];
	} else if ([keyPath isEqualToString:@"/results/created_at"]) {
		currentMessage.createdDate = [self dateWithSearchString:value];
	} else if ([keyPath isEqualToString:@"/results/text"]) {
		currentMessage.content = value;
	} else if ([keyPath isEqualToString:@"/results/from_user"]) { 
		currentMessage.screenName = value;
	} else if ([keyPath isEqualToString:@"/results/profile_image_url"]) { 
		currentMessage.avatar = value;
	}
}


@end
