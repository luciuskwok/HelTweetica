//
//  LKUploadPictureAction.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 8/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKUploadPictureAction.h"


@implementation LKUploadPictureAction
@synthesize media, username, password;

- (void)dealloc {
	[media release];
	[username release];
	[password release];
	[super dealloc];
}

- (id)delegate {
	return delegate;
}

- (void)setDelegate:(id <LKUploadPictureActionDelegate>)x {
	delegate = x;
}

- (NSString *)multipartBoundaryString {
	return @"----This_is_a_boundary----";
}

- (NSData *)dataWithMultipartEncodedParameters:(NSDictionary *)parameters {
	NSMutableData *data = [NSMutableData data];
	NSString *boundary = [[self multipartBoundaryString] stringByAppendingString:@"\n"];
	
	NSArray *keys = [parameters allKeys];
	for (NSString *key in keys) {
		id value = [parameters objectForKey:key];
		NSString *s;
		
		// Add boundary to beginning of section.
		[data appendData:[boundary dataUsingEncoding:NSUTF8StringEncoding]];
		
		// Add content header and data.
		if ([value isKindOfClass:[NSString class]]) {
			s = [NSString stringWithFormat:@"Content-disposition: form-data; Name=\"%@\"\n\n%@\n", key, value];
			[data appendData:[s dataUsingEncoding:NSUTF8StringEncoding]];
		} else if ([value isKindOfClass:[NSData class]]) {
			s = [NSString stringWithFormat:@"Content-disposition: form-data; Name=\"%@\"\nContent-transfer-encoding: binary\n\n", key];
			[data appendData:[s dataUsingEncoding:NSUTF8StringEncoding]];
			[data appendData:value];
		}
		
	}
	
	// Add boundary to close last section.
	[data appendData:[boundary dataUsingEncoding:NSUTF8StringEncoding]];
	
	return data;
}

- (void)startUpload {
	// Set parameters.
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	[parameters setObject:username forKey:@"username"];
	[parameters setObject:password forKey:@"password"];
	[parameters setObject:media forKey:@"media"];
	
	// Set up URL request.
	NSString *urlString = @"http://twitpic.com/api/upload";
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]] autorelease];
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", [self multipartBoundaryString]] forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody: [self dataWithMultipartEncodedParameters:parameters]];
	
	// Create and start the download connection
	self.connection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately: YES] autorelease];
	isLoading = YES;
	
	// Delegate is retained while connection is active.
	[delegate retain];
}

- (void)dataFinishedLoading:(NSData *)data {
	// Parse returned XML.
	NSString *xml = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	NSScanner *scanner = [NSScanner scannerWithString:xml];
	NSString *value;
	
	[scanner scanUpToString:@"<rsp stat=\"" intoString:nil];
	[scanner scanUpToString:@"\">" intoString:&value];
	
	if ([value isEqual:@"ok"]) {
		// Success
		[scanner scanUpToString:@"<mediaurl>" intoString:nil];
		[scanner scanUpToString:@"</meduaurl>" intoString:&value];
		
		// Notify delegate.
		[delegate action:self didUploadPictureWithURL:value];
	} else {
		// Error
		int errorCode = 0;
		NSString *errorDescription = nil;
		
		[scanner scanUpToString:@"code=\"" intoString:nil];
		[scanner scanInt:&errorCode];
		[scanner scanUpToString:@"msg=\"" intoString:nil];
		[scanner scanUpToString:@"\"" intoString:&errorDescription];

		// Notify delegate.
		[delegate action:self didFailWithErrorCode:errorCode description:errorDescription];
	}
}

- (void)failedWithError:(NSError *)error {
	[delegate action:self didFailWithErrorCode:[error code] description:[error localizedDescription]];
}

@end
