//
//  LKShrinkURLAction.m
//  HelTweetica-iPad
//
//  Created by Lucius Kwok on 7/31/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKShrinkURLAction.h"


@implementation LKShrinkURLAction

- (id)delegate {
	return delegate;
}

- (void)setDelegate:(id <LKShrinkURLActionDelegate>)x {
	delegate = x;
}

+ (NSSet *)actionsToShrinkURLsWithPrefix:(NSString *)prefix inString:(NSString *)string minLength:(int)minLength {
	NSMutableSet *actions = [NSMutableSet set];
	
	// Scanner setup.
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSCharacterSet *nonURLSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n\"'"];
	[scanner setCharactersToBeSkipped:nil];
	NSString *longUrl;
	
	while ([scanner isAtEnd] == NO) {
		[scanner scanUpToString:prefix intoString:nil];
		if ([scanner scanUpToCharactersFromSet:nonURLSet intoString:&longUrl]) {
			if (longUrl.length >= minLength) {
				LKShrinkURLAction *action = [[[LKShrinkURLAction alloc] init] autorelease];
				action.identifier = longUrl;
				[actions addObject:action];
			}
		}
	}
	return actions;
}

+ (NSSet *)actionsToShrinkURLsInString:(NSString *)string {
	const int kMinLengthToShorten = 23;
	
	NSSet *plain = [self actionsToShrinkURLsWithPrefix:@"http://" inString:string minLength:kMinLengthToShorten];
	NSSet *ssl = [self actionsToShrinkURLsWithPrefix:@"https://" inString:string minLength:kMinLengthToShorten];
	
	return [plain setByAddingObjectsFromSet:ssl];
}

- (void)load {
	// bit.ly requires an API key so we don't use this: http://api.bit.ly/v3/shorten?format=txt&longUrl=
	// TinyURL http://tinyurl.com/api-create.php?url=SOURCE_URL
	
	// URL shortener setup.
	NSString *shortenerPrefix = @"http://is.gd/api.php?longurl=";
	NSString *request = [shortenerPrefix stringByAppendingString:[identifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	
	[self loadURL:[NSURL URLWithString:request]];
}

- (void)dataFinishedLoading:(NSData *)data {
	NSString *shortURL = [[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding] autorelease];
	[delegate action:self didReplaceLongURL:identifier withShortURL:shortURL];
}

- (void)failedWithError:(NSError *)error {
	[delegate action:self didFailWithError:error];
}


@end
