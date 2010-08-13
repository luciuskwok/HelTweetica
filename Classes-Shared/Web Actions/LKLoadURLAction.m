//
//  LKLoadURLAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 7/24/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKLoadURLAction.h"


@implementation LKLoadURLAction
@synthesize url, connection, receivedData, identifier, delegate;

- (id)initWithURL:(NSURL *)anURL {
	self = [super init];
	if (self) {
		self.url = anURL;
	}
	return self;
}

- (void)dealloc {
	[url release];
	[connection release];
	[receivedData release];
	[identifier release];
	[super dealloc];
}

- (void)start {
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	[request setHTTPMethod:@"GET"];
	
	// Create the download connection
	self.connection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES] autorelease];
	isLoading = YES;
	
	// Delegate is retained while connection is active.
	[delegate retain];
}

- (void) cancel {
	[self.connection cancel];
	isLoading = NO;
	self.receivedData = nil; // Don't keep partial data.
}

- (void)dataFinishedLoading:(NSData *)data {
	// Send message to delegate with data.
	if ([delegate respondsToSelector:@selector(loadURLAction:didLoadData:)])
		[delegate loadURLAction:self didLoadData:receivedData];
}

- (void)failedWithError:(NSError *)error {
	// Send message to delegate of failure.
	if ([delegate respondsToSelector:@selector(loadURLAction:didFailWithError:)])
		[delegate loadURLAction:self didFailWithError:error];
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
	
	// Allow subclasses to process data.
	[self dataFinishedLoading:receivedData];
	
	// Clean up
	[delegate release];
	self.connection = nil;
	self.receivedData = nil;
}	

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {
	isLoading = NO;
	statusCode = 0; // Status code is not valid with this kind of error, which is typically a timeout or no network error.
	
	// Allow subclasses to handle error.
	[self failedWithError:error];

	// Clean up
	[delegate release];
	self.connection = nil;
	self.receivedData = nil;
}

@end
