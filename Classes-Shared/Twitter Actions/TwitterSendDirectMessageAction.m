//
//  TwitterSendDirectMessageAction.m
//  HelTweetica-iPad
//
//  Created by Brian Papa on 8/31/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterSendDirectMessageAction.h"
#import "LKJSONParser.h"

@implementation TwitterSendDirectMessageAction

@synthesize screenNameTo;

- (id)initWithText:(NSString*)text to:(NSString*)screenName {
	if (self = [super init]) {
		self.twitterMethod = @"direct_messages/new";
		self.screenNameTo = screenName;
		
		self.parameters = [NSMutableDictionary dictionary];
		[parameters setObject:screenName forKey:@"screen_name"];
		[parameters setObject:text forKey:@"text"];
	}
	return self;	
}

- (void) start {
	[self startPostRequest];
}

- (void) parseReceivedData:(NSData*)data {
	LKJSONParser *parser = [[[LKJSONParser alloc] initWithData:data] autorelease];
	parser.delegate = self;
	[parser parse];
}

#pragma mark Values

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([parser.keyPath isEqualToString:@"/error"]) {
		NSString *errorMessage = [NSString stringWithFormat:@"%@ doesn't follow you.",self.screenNameTo];
		NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Direct Message Error",
										 @"title",errorMessage,@"message",errorMessage,NSLocalizedDescriptionKey,nil];
		
		self.twitterAPIError = [NSError errorWithDomain:@"com.felttip" 
												   code:TwitterActionErrorCodeDirectMessageFailedNoFollow
											   userInfo:errorDictionary]; 
	} 
}

@end
