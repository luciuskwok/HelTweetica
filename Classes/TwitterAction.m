//
//  TwitterAction.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterAction.h"
#import "OAuthClient.h"
#import "HelTweeticaAppDelegate.h"


// You will need to supply your own credentials in the file imported here:
#import "(HelTweeticaConsumerToken).h"
// The file shoud contain the following two lines:
// #define kConsumerKey @"xxxxxxxxxxxxxxxx"
// #define kConsumerSecret @"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"


@implementation TwitterAction
@synthesize consumerToken, consumerSecret, twitterMethod, parameters, connection, receivedData, statusCode, isLoading;
@synthesize completionTarget, completionAction, delegate;

#pragma mark -

- (id) init {
	self = [super init];
	if (self) {
		appDelegate = [[UIApplication sharedApplication] delegate];
	}
	return self;
}

- (void) dealloc {
	[consumerToken release];
	[consumerSecret release];
	[twitterMethod release];
	[parameters release];
	[connection release]; // Note that connection retains its delegate (which is self) until it is cancelled or completes.
	[receivedData release];
	[super dealloc];
}


#pragma mark -
#pragma mark URL encoding convenience methods

+ (NSString*) URLEncodeString: (NSString*) aString {
	NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aString, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
 	return [result autorelease];
}

+ (NSString*) stringWithEncodedParameters:(NSDictionary*)inParameters {
	NSMutableString *s = [NSMutableString string];
	NSArray *allKeys = [inParameters allKeys];
	NSString *key, *value;
	BOOL firstParameter = YES;
	for (key in allKeys) {
		if (firstParameter) {
			firstParameter = NO;
		} else {
			[s appendString:@"&"];
		}
		value = [TwitterAction URLEncodeString: [inParameters objectForKey:key]];
		[s appendFormat: @"%@=%@", key, value];
	}
	return s;
}

+ (NSURL*) URLWithBase: (NSString*) baseString query: (NSDictionary*) inParameters {
	NSMutableString *s = [[[NSMutableString alloc] initWithString: baseString] autorelease];
	if ([inParameters count] > 0) {
		NSString *encodedParameters = [TwitterAction stringWithEncodedParameters:inParameters];
		[s appendFormat:@"?%@", encodedParameters];
	}
	return [NSURL URLWithString:s];
}

#pragma mark -

- (void) start {
	NSLog (@"Subclasses should override the -[TwitterAction start] method.");
}

- (void) startURLRequest:(NSMutableURLRequest*)request {
	// Cancel any pending requests.
	[self cancel];
	
	// OAuth Authorization
	OAuthClient *oauth = [[[OAuthClient alloc] initWithClientKey:kConsumerKey clientSecret:kConsumerSecret] autorelease];
	[oauth setUserKey:consumerToken userSecret: consumerSecret];
	NSString *authorization = [oauth authorizationHeaderWithURLRequest: request];
	[request setValue: authorization forHTTPHeaderField:@"Authorization"];
	
	// Create the download connection
	self.connection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES] autorelease];
	isLoading = YES;
	
	// Retain delegate until the NSURLConnection returns with a finished or error callback
	[delegate retain];
	[appDelegate incrementNetworkActionCount];
}

- (void) startPostRequest {
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.twitter.com/1/%@.json", twitterMethod]]; // version 1 only
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	[request setHTTPMethod:@"POST"];
	
	// Encode parameters and put into body
	if ([parameters count] > 0) {
		NSString *encodedParameters = [TwitterAction stringWithEncodedParameters: parameters];
		[request setHTTPBody: [encodedParameters dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	[self startURLRequest:request];
}


- (void) startGetRequest {
	NSString *base = [NSString stringWithFormat:@"http://api.twitter.com/1/%@.json", twitterMethod]; // version 1 only
	NSURL *url = [TwitterAction URLWithBase:base query:parameters];
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
	[request setHTTPMethod:@"GET"];
	[self startURLRequest:request];
}

- (void) cancel {
	[self.connection cancel];
	isLoading = NO;
	[appDelegate decrementNetworkActionCount];
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response {
	if (aConnection != connection) return;
	if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
		statusCode = [(NSHTTPURLResponse*) response statusCode];
		/* HTTP Status Codes
			200 OK
			400 Bad Request
			401 Unauthorized (bad username or password)
			403 Forbidden
			404 Not Found
			502 Bad Gateway
			503 Service Unavailable
		 */
	}
	if (receivedData == nil) {
		receivedData = [[NSMutableData alloc] init];
	} else {
		NSMutableData *theData = self.receivedData;
		[theData setLength:0];
	}
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data {
	if (aConnection != connection) return;
	[self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection {
	if (aConnection != connection) return;
	isLoading = NO;
	
	// Parse the received data
	[self parseReceivedData:receivedData];
	
	// Call the did finish loading on delegate
	if ([delegate respondsToSelector:@selector(twitterActionDidFinishLoading:)])
		[delegate twitterActionDidFinishLoading:self];
	
	// Call the completion action on the target
	if ([completionTarget respondsToSelector:completionAction]) {
		[completionTarget performSelector:completionAction withObject:self];
	}
	
	[delegate release];
	self.connection = nil;
	[appDelegate decrementNetworkActionCount];
}	

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {
	if (aConnection != connection) return;
	isLoading = NO;
	
	// Call the did fail on delegate
	if ([delegate respondsToSelector:@selector(twitterAction:didFailWithError:)])
		[delegate twitterAction:self didFailWithError:error];

	[delegate release];
	self.connection = nil;
	[appDelegate decrementNetworkActionCount];
}

- (void) parseReceivedData:(NSData*)data {
}

// For the debugger, descrption prints out some info about the object instance.
- (NSString*) description {
	return [NSString stringWithFormat: @"method: %@", twitterMethod];
}

@end
