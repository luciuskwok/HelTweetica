//
//  HelTweeticaAppTests.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/26/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "HelTweeticaAppTests.h"
#import "TwitterMessageJSONParser.h"


@implementation HelTweeticaAppTests

- (void) testAppDelegate {
	id app_delegate = [[UIApplication sharedApplication] delegate];
	STAssertNotNil(app_delegate, @"Cannot find the application delegate.");
}

- (void) testParser {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"json"];
	NSError *error = nil;
	NSData *testJSON = [NSData dataWithContentsOfFile:path options:0 error:&error];
	TwitterMessageJSONParser *parser = [[TwitterMessageJSONParser alloc] init];
	NSArray *messages = [parser messagesWithJSONData:testJSON];
	[parser release];
	
    STAssertTrue ([messages count] > 0,@"TwitterMessageJSONParser failed to parse JSON into any messages.");
}


@end
