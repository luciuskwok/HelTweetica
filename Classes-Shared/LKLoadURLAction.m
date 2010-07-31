//
//  LKLoadURLAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 7/24/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKLoadURLAction.h"


@implementation LKLoadURLAction
@synthesize connection, receivedData, identifier, delegate;

- (void)dealloc {
	[connection release];
	[receivedData release];
	[identifier release];
	[super dealloc];
}

- (void)loadURL:(NSURL*)url {
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	[request setHTTPMethod:@"GET"];
	
	// Create the download connection
	self.connection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES] autorelease];
	isLoading = YES;
	
	// Delegate is retained while connection is active.
	[delegate retain];
}

#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response {
	if ([response isKindOfClass: [NSHTTPURLResponse class]])
		statusCode = [(NSHTTPURLResponse*) response statusCode];
	self.receivedData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data {
	[self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection {
	isLoading = NO;
	
	// Send message to delegate with data.
	if ([delegate respondsToSelector:@selector(loadURLAction:didLoadData:)])
		[delegate loadURLAction:self didLoadData:receivedData];
	
	// Clean up
	[delegate release];
	self.connection = nil;
	self.receivedData = nil;
}	

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {
	isLoading = NO;
	statusCode = 0; // Status code is not valid with this kind of error, which is typically a timeout or no network error.
	
	// Send message to delegate of failure.
	if ([delegate respondsToSelector:@selector(loadURLAction:didFailWithError:)])
		[delegate loadURLAction:self didFailWithError:error];

	// Clean up
	[delegate release];
	self.connection = nil;
	self.receivedData = nil;
}

@end
