//
//  LKUploadPictureAction.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 8/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKUploadPictureAction.h"


@implementation LKUploadPictureAction
@synthesize username, password, media, fileType;

- (id)initWithFile:(NSURL *)fileURL {
	self = [super init];
	if (self) {
		NSError *error = nil;
		self.media = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMapped error:&error];
		if (media == nil)
			NSLog (@"Error opening file %@: %@", fileURL, error);
		self.fileType = [fileURL pathExtension];
	}
	return self;
}

- (void)dealloc {
	[username release];
	[password release];
	[media release];
	[fileType release];
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

- (NSData *)dataWithMultipartEncodedParameters:(NSDictionary *)parameters imageType:(NSString *)imageType {
	NSMutableData *data = [NSMutableData data];
	NSData *boundary = [[NSString stringWithFormat:@"--%@\r\n", [self multipartBoundaryString]] dataUsingEncoding:NSUTF8StringEncoding];
	NSData *crlf = [NSData dataWithBytes:"\r\n" length:2];
	
	// Initial boundary.
	[data appendData:boundary];
	
	NSArray *keys = [parameters allKeys];
	for (NSString *key in keys) {
		id value = [parameters objectForKey:key];
		NSString *s;
		
		// Add content header and data.
		if ([value isKindOfClass:[NSString class]]) {
			s = [NSString stringWithFormat:
				 @"Content-Disposition: form-data; name=\"%@\"\r\n"
				 @"\r\n"
				 @"%@\r\n", 
				 key, value];
			[data appendData:[s dataUsingEncoding:NSUTF8StringEncoding]];
		} else if ([value isKindOfClass:[NSData class]]) {
			s = [NSString stringWithFormat:
				 @"Content-Disposition: form-data; name=\"%@\"; filename=\"picture.jpg\"\r\n" 
				 @"Content-Type: image/%@\r\n"
				 @"Content-Transfer-Encoding: binary\r\n\r\n", 
				 imageType, key];
			[data appendData:[s dataUsingEncoding:NSUTF8StringEncoding]];
			[data appendData:value];
			[data appendData:crlf];
		}
		
		// Boundary after each part..
		[data appendData:boundary];
	}
	
	
	return data;
}

- (NSData *)dataPartWithName:(NSString *)name value:(NSString *)value {
	NSString *string = [NSString stringWithFormat:
						@"Content-Disposition: form-data; name=\"%@\"\r\n"
						@"\r\n"
						@"%@\r\n", 
						name, value];
	return [string dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)dataPartWithName:(NSString *)name data:(NSData *)data fileType:(NSString *)aFileType {
	NSString *string = [NSString stringWithFormat:
						@"Content-Disposition: form-data; name=\"%@\"; filename=\"1.%@\"\r\n" 
						@"Content-Type: image/%@\r\n"
						@"Content-Transfer-Encoding: binary\r\n\r\n", 
						name, aFileType, aFileType];
	NSMutableData *result = [NSMutableData dataWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
	[result appendData:data];
	[result appendBytes:"\r\n" length:2];
	return result;
}

- (void)startUpload {
	// Set up URL request.
	NSURL *url = [NSURL URLWithString:@"http://twitpic.com/api/upload"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
	[request setHTTPShouldHandleCookies:NO];
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", [self multipartBoundaryString]] forHTTPHeaderField:@"Content-Type"];
	
	// Set parameters.
	NSMutableData *httpBody = [NSMutableData data];
	NSData *boundary = [[NSString stringWithFormat:@"--%@\r\n", [self multipartBoundaryString]] dataUsingEncoding:NSUTF8StringEncoding];
	[httpBody appendData:boundary];
	[httpBody appendData:[self dataPartWithName:@"username" value:username]];
	[httpBody appendData:boundary];
	[httpBody appendData:[self dataPartWithName:@"password" value:password]];
	[httpBody appendData:boundary];
	[httpBody appendData:[self dataPartWithName:@"media" data:media fileType:fileType]];
	[httpBody appendData:boundary];
	[request setHTTPBody: httpBody];
	
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
	[scanner scanString:@"<rsp stat=\"" intoString:nil];
	[scanner scanUpToString:@"\">" intoString:&value];
	
	if ([value isEqual:@"ok"]) {
		// Success
		[scanner scanUpToString:@"<mediaurl>" intoString:nil];
		[scanner scanString:@"<mediaurl>" intoString:nil];
		[scanner scanUpToString:@"</mediaurl>" intoString:&value];
		
		// Notify delegate.
		[delegate action:self didUploadPictureWithURL:value];
	} else {
		// Error
		int errorCode = 0;
		NSString *errorDescription = nil;
		
		[scanner scanUpToString:@"code=\"" intoString:nil];
		[scanner scanString:@"code=\"" intoString:nil];
		[scanner scanInt:&errorCode];
		[scanner scanUpToString:@"msg=\"" intoString:nil];
		[scanner scanString:@"msg=\"" intoString:nil];
		[scanner scanUpToString:@"\"" intoString:&errorDescription];

		// Notify delegate.
		[delegate action:self didFailWithErrorCode:errorCode description:errorDescription];
	}
}

- (void)failedWithError:(NSError *)error {
	[delegate action:self didFailWithErrorCode:[error code] description:[error localizedDescription]];
}

@end
