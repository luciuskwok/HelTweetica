//
//  TwitterLoginAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/1/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
	
	// Set consumer token to empty string so it uses OAuth but doesn't include it in the parameters
	self.consumerToken = @"";
	
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
