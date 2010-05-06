//
//  Instapaper.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/12/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "Instapaper.h"


@interface Instapaper (PrivateMethods)
- (NSURL*) URLWithBase: (NSString*) baseString query: (NSDictionary*) parameters;
@end

@implementation Instapaper
@synthesize downloadConnection;


+ (Instapaper*) sharedInstapaper {
	static Instapaper *_sharedInstapaper = nil;
	if (_sharedInstapaper == nil) {
		_sharedInstapaper = [[Instapaper alloc] init];
	}
	return _sharedInstapaper;
}

- (id)init {
	self = [super init];
	if (self) {
		appDelegate = [[UIApplication sharedApplication] delegate];
	}
	return self;
}	

- (void) cancel {
	[self.downloadConnection cancel];
	isLoading = NO;
}

- (void) callMethod: (NSString*) method withParameters: (NSDictionary*) parameters {
	// Cancel any pending requests.
	[self cancel];
	
	NSString *base = [NSString stringWithFormat:@"https://www.instapaper.com/api/%@", method];
	NSURL *url = [self URLWithBase:base query:parameters];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	[request setHTTPMethod:@"GET"];
	
	// Create the download connection
	[appDelegate incrementNetworkActionCount];
	self.downloadConnection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES] autorelease];
	isLoading = YES;
	
	// Clean up
	[request release];
}

- (void) authenticateUsername:(NSString*)username password:(NSString*)password {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	if (username != nil) [parameters setObject:username forKey:@"username"];
	if (password != nil) [parameters setObject:password forKey:@"password"];

	[self callMethod:@"authenticate" withParameters: parameters];
}

- (void) addURL:(NSURL*)url withUsername:(NSString*)username password:(NSString*)password {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	if (username != nil) [parameters setObject:username forKey:@"username"];
	if (password != nil) [parameters setObject:password forKey:@"password"];
	if (url != nil) [parameters setObject:[url absoluteString] forKey:@"url"];
	[parameters setObject:@"1" forKey:@"auto-title"];
	
	[self callMethod:@"add" withParameters: parameters];
}

#pragma mark -

- (NSString*) URLEncodeString: (NSString*) aString {
	NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aString, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
 	return [result autorelease];
}

- (NSURL*) URLWithBase: (NSString*) baseString query: (NSDictionary*) parameters {
	NSMutableString *s = [[NSMutableString alloc] initWithString: baseString];
	BOOL firstParameter = YES;
	
	if ([parameters count] > 0) {
		NSArray *allKeys = [parameters allKeys];
		NSString *key, *value;
		for (key in allKeys) {
			if (firstParameter) {
				[s appendString:@"?"];
				firstParameter = NO;
			} else {
				[s appendString:@"&"];
			}
			value = [self URLEncodeString: [parameters objectForKey:key]];
			[s appendFormat: @"%@=%@", key, value];
		}
	}
	
	NSURL *url = [NSURL URLWithString:s];
	[s release];
	return url;
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		downloadStatusCode = [(NSHTTPURLResponse*) response statusCode];
		if (downloadStatusCode == 403) { // Authentication failed
			[nc postNotificationName:@"instapaperAuthenticationFailed" object:self];
		} else if (downloadStatusCode >= 400) {
			NSError *error = [NSError errorWithDomain:@"Network" code:downloadStatusCode userInfo:nil];
			[nc postNotificationName:@"instapaperNetworkError" object:error];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (connection != downloadConnection) return;
	
	[appDelegate decrementNetworkActionCount];
	isLoading = NO;
	self.downloadConnection = nil;
	
	if (downloadStatusCode < 400) 
		[[NSNotificationCenter defaultCenter] postNotificationName:@"instapaperSuccess" object:self];
}	

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if (connection != downloadConnection) return;
	
	[appDelegate decrementNetworkActionCount];
	self.downloadConnection = nil;
	isLoading = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"instapaperNetworkError" object:error];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)aConnection willCacheResponse:(NSCachedURLResponse *)aResponse {
	return nil; // Don't cache any responses for TwitterActions.
}


@end
