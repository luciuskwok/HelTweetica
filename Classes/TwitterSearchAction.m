//
//  TwitterSearchAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterSearchAction.h"


@implementation TwitterSearchAction
@synthesize query;
@synthesize messages, currentMessage, keyPath, receivedTimestamp;


- (id)initWithQuery:(NSString *)aQuery {
	self = [super init];
	if (self) {
		self.query = aQuery;
		
		NSMutableDictionary *theParameters = [NSMutableDictionary dictionary];
		[theParameters setObject:aQuery forKey:@"q"];
		[theParameters setObject:@"100" forKey:@"rpp"]; // Results per page.
		
		self.parameters = theParameters;
		self.messages = [NSMutableArray array];
	}
	return self;
}

- (void) dealloc {
	[query release];
	[messages release];
	[currentMessage release];
	[keyPath release];
	[receivedTimestamp release];
	[super dealloc];
}

// Search uses a completely different URL from the other Twitter methods.
- (void) start {
	NSString *base = @"http://search.twitter.com/search.json"; 
	NSURL *url = [TwitterAction URLWithBase:base query:parameters];
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	[request setHTTPMethod:@"GET"];
	[request setValue:@"HelTweetica/1.0" forHTTPHeaderField:@"User-Agent"];
	[self startURLRequest:request];
}

- (void) parseReceivedData:(NSData*)data {
	if (statusCode < 400) {
		LKJSONParser *parser = [[LKJSONParser alloc] initWithData:data];
		parser.delegate = self;
		self.receivedTimestamp = [NSDate date];
		[parser parse];
		[parser release];
	}
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
