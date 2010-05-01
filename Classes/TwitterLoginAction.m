//
//  TwitterLoginAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterLoginAction.h"


@implementation TwitterLoginAction
@synthesize username, password, token, secret;


- (id) initWithUsername:(NSString*)aUsername password:(NSString*)aPassword {
	if (self = [super init]) {
		self.username = aUsername;
		self.password = aPassword;
	}
	return self;
}

- (void) dealloc {
	[username release];
	[password release];
	[super dealloc];
}

- (void) start {
	NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/oauth/access_token"];
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	[request setHTTPMethod:@"POST"];
	
	NSString *encodedUsername = [TwitterAction URLEncodeString: self.username];
	NSString *encodedPassword = [TwitterAction URLEncodeString: self.password];
	NSString *postBody = [NSString stringWithFormat:@"x_auth_username=%@&x_auth_password=%@&x_auth_mode=client_auth", encodedUsername, encodedPassword];
	[request setHTTPBody: [postBody dataUsingEncoding:NSUTF8StringEncoding]];
	
	[self startURLRequest:request];
}

- (void) parseReceivedData:(NSData*)data {
	NSString *resultString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	if (resultString != nil) {
		// Store tokens
		NSCharacterSet *delimiters = [NSCharacterSet characterSetWithCharactersInString:@"=&"];
		NSArray *components = [resultString componentsSeparatedByCharactersInSet:delimiters];
		if (components.count >= 4) {
			NSString *key;
			for (int index = 0; index < components.count - 1; index+=2) {
				key = [components objectAtIndex:index];
				if ([key isEqualToString: @"oauth_token"]) {
					self.token = [[components objectAtIndex: index + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				} else if ([key isEqualToString: @"oauth_token_secret"]) {
					self.secret = [[components objectAtIndex: index + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				} else if ([key isEqualToString: @"screen_name"]) {
					self.username = [[components objectAtIndex: index + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				}
			}
			
		}
	}
}


@end
