//
//  OAuthClient.m
//
//  Created by Lucius Kwok on 3/30/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* This version of the OAuth client only supports HMAC-SHA1 as the signature provider. */

#import "OAuthClient.h"
#import <CommonCrypto/CommonHMAC.h>

// Test
//#import "OAuthConsumer.h"


@interface OAuthClient (Private)
- (NSString *) URLEncodeString: (NSString*) aString;
- (NSString *) signatureBaseStringWithURLRequest: (NSURLRequest*) urlRequest;
- (NSString *) signatureWithText: (NSString*) aText secret: (NSString*) aSecret;
- (NSString *) base64encode: (NSData*) data;
@end

@implementation OAuthClient
@synthesize clientKey, clientSecret, userKey, userSecret, realm, callback, verifier;

- (id) initWithClientKey: (NSString*) aClientKey clientSecret: (NSString*) aClientSecret {
	if (self = [super init]) {
		self.clientKey = aClientKey;
		self.clientSecret = aClientSecret;
		
		/* 8.  Nonce and Timestamp
			 Unless otherwise specified by the Service Provider, the timestamp is expressed in the number of seconds since January 1, 1970 00:00:00 GMT. The timestamp value MUST be a positive integer and MUST be equal or greater than the timestamp used in previous requests.
			 The Consumer SHALL then generate a Nonce value that is unique for all requests with that timestamp. A nonce is a random string, uniquely generated for each request. The nonce allows the Service Provider to verify that a request has never been made before and helps prevent replay attacks when requests are made over a non-secure channel (such as HTTP). */
		CFUUIDRef uuid = CFUUIDCreate(NULL);
		nonce = (NSString*) CFUUIDCreateString(NULL, uuid);
		CFRelease (uuid);
		
		timestamp = [[NSString alloc] initWithFormat:@"%d", time(NULL)];
	}
	return self;
}

- (void) dealloc {
	[clientKey release];
	[clientSecret release];
	[userKey release];
	[userSecret release];
	[nonce release];
	[timestamp release];
	[realm release];
	
	[super dealloc];
}

- (void) setUserKey: (NSString *) aKey userSecret: (NSString*) aSecret {
	self.userKey = aKey;
	self.userSecret = aSecret;
}

- (NSString *) authorizationHeaderWithURLRequest: (NSURLRequest*) aRequest {
	// Create percent-escaped version of strings
	NSString *clientKeyEncoded = [self URLEncodeString: clientKey];
	NSString *clientSecretEncoded = [self URLEncodeString: clientSecret];
	NSString *userKeyEncoded = [self URLEncodeString: userKey];
	NSString *userSecretEncoded = (userSecret != nil) ? [self URLEncodeString: userSecret] : @"";

	// Create signature base.
	NSString *base = [self signatureBaseStringWithURLRequest: aRequest];
	NSString *secret = [NSString stringWithFormat:@"%@&%@", clientSecretEncoded, userSecretEncoded];
	NSString *signature = [self signatureWithText: base secret: secret];
 	
	// Create the Authorization header
	NSMutableString *header = [NSMutableString stringWithString: @"OAuth "];
	if (realm != nil)
		[header appendFormat:@"realm=\"%@\", ", [self URLEncodeString: realm]];
	[header appendFormat:@"oauth_consumer_key=\"%@\", ", clientKeyEncoded];
	if (userKeyEncoded != nil)
		[header appendFormat:@"oauth_token=\"%@\", ", userKeyEncoded];
	[header appendString:@"oauth_signature_method=\"HMAC-SHA1\", "];
	[header appendFormat:@"oauth_signature=\"%@\", ", [self URLEncodeString:signature]];
	[header appendFormat:@"oauth_timestamp=\"%@\", ", timestamp];
	[header appendFormat:@"oauth_nonce=\"%@\", ", nonce];
	if (callback != nil)
		[header appendFormat:@"oauth_callback=\"%@\", ", [self URLEncodeString: callback]];
	if (verifier != nil)
		[header appendFormat:@"oauth_verifier=\"%@\", ", [self URLEncodeString: verifier]];
	[header appendString:@"oauth_version=\"1.0\""];
		
    return header;
}

#pragma mark -

- (NSString*) URLEncodeString: (NSString*) aString {
	if (aString == nil) return nil;
	
	CFStringRef cfstr = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aString, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
	NSString *result = [NSString stringWithString: (NSString*) cfstr];
	CFRelease (cfstr);
 	return result;
}

- (NSString*) signatureBaseStringWithURLRequest: (NSURLRequest*) urlRequest { // Tested on 2010-03-31 5:40 pm -LK.
	/*	9.1.1.  Normalize Request Parameters
		 The request parameters are collected, sorted and concatenated into a normalized string:
		   - Parameters in the OAuth HTTP Authorization header excluding the realm parameter.
		   - Parameters in the HTTP POST request body (with a content-type of application/x-www-form-urlencoded).
		   - HTTP GET parameters added to the URLs in the query part (as defined by [RFC3986] section 3).
		 The oauth_signature parameter MUST be excluded.
		 
		 The parameters are normalized into a single string as follows:
		 1. Parameters are sorted by name, using lexicographical byte value ordering. If two or more parameters share the same name, they are sorted by their value. 
		 2. Parameters are concatenated in their sorted order into a single string. For each parameter, the name is separated from the corresponding value by an '=' character (ASCII code 61), even if the value is empty. Each name-value pair is separated by an '&' character (ASCII code 38). */	 
	
	// Create an array of parameters (key-value pairs already in 'key="value"' format)
	NSMutableArray *parameters = [[NSMutableArray alloc] init];
	[parameters addObject: [NSString stringWithFormat:@"oauth_consumer_key=%@", [self URLEncodeString:clientKey]]];
	[parameters addObject: [NSString stringWithFormat:@"oauth_nonce=%@", nonce]];
	[parameters addObject: [NSString stringWithFormat:@"oauth_timestamp=%@", timestamp]];
	[parameters addObject: @"oauth_signature_method=HMAC-SHA1"];
	[parameters addObject: @"oauth_version=1.0"];
	if (userKey != nil) 
		[parameters addObject: [NSString stringWithFormat:@"oauth_token=%@", [self URLEncodeString:userKey]]];
	if (callback != nil) 
		[parameters addObject: [NSString stringWithFormat:@"oauth_callback=%@", [self URLEncodeString:callback]]];
	if (verifier != nil) 
		[parameters addObject: [NSString stringWithFormat:@"oauth_verifier=%@", [self URLEncodeString:verifier]]];
	
	// Also include parameters already in the HTTP body or query in the URL.
	NSString *method = [urlRequest HTTPMethod];
	NSString *encodedParameters = nil;
	if ([method isEqual:@"GET"] || [method isEqual:@"DELETE"]) {
		encodedParameters = [[urlRequest URL] query];
	} else {
		NSData *body = [urlRequest HTTPBody];
		if ((body != nil) && ([body length] != 0))  
			encodedParameters = [[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] autorelease];
	}
	if (encodedParameters != nil) 
		[parameters addObjectsFromArray: [encodedParameters componentsSeparatedByString:@"&"]];
	
	// Sort
	[parameters sortUsingSelector:@selector(compare:)];
    NSString *normalizedParamters = [parameters componentsJoinedByString:@"&"];
    [parameters release];
	
   /* 9.1.2.  Construct Request URL
		 The Signature Base String includes the request absolute URL, tying the signature to a specific endpoint. The URL used in the Signature Base String MUST include the scheme, authority, and path, and MUST exclude the query and fragment as defined by [RFC3986] section 3.
		 If the absolute request URL is not available to the Service Provider (it is always available to the Consumer), it can be constructed by combining the scheme being used, the HTTP Host header, and the relative HTTP request URL. If the Host header is not available, the Service Provider SHOULD use the host name communicated to the Consumer in the documentation or other means.
		 The Service Provider SHOULD document the form of URL used in the Signature Base String to avoid ambiguity due to URL normalization. Unless specified, URL scheme and authority MUST be lowercase and include the port number; http default port 80 and https default port 443 MUST be excluded. */
	NSString *baseURL = [[[[urlRequest URL] absoluteString] componentsSeparatedByString:@"?"] objectAtIndex: 0]; // po baseURL

	/* 9.1.3.  Concatenate Request Elements
		 The following items MUST be concatenated in order into a single string. Each item is encoded and separated by an '&' character (ASCII code 38), even if empty.
			1. The HTTP request method used to send the request. Value MUST be uppercase, for example: HEAD, GET , POST, etc.
			2. The request URL from Section 9.1.2.
			3. The normalized request parameters string from Section 9.1.1.
		 See Signature Base String example in Appendix A.5.1.
	 */
 	return [NSString stringWithFormat:@"%@&%@&%@", method, [self URLEncodeString:baseURL], [self URLEncodeString: normalizedParamters]];
}

- (NSString *) signatureWithText: (NSString*) aText secret: (NSString*) aSecret {
	NSData *secretData = [aSecret dataUsingEncoding:NSUTF8StringEncoding];
	NSData *textData = [aText dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableData *hash = [NSMutableData dataWithLength:20];
	CCHmac(kCCHmacAlgSHA1, [secretData bytes], [secretData length], [textData bytes], [textData length], [hash mutableBytes]);
	
	NSString *encodedHash = [OAuthClient base64encode: hash];
	return encodedHash;
}

#pragma mark Class methods

+ (NSString *)base64encode:(NSData *)data {
	if (data == nil) return nil;
	if ([data length] == 0) return @"";
	
	static const char *table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	const unsigned char *source = [data bytes];
	const unsigned int sourceLength = [data length];
	unsigned char a[3], b[4];
	unsigned int sourceIndex = 0;
	
	NSMutableString *result = [NSMutableString stringWithCapacity: sourceLength * 4 / 3 + 1];
	
	while (sourceIndex < sourceLength) {
		// Load buffer with binary data
		a[0] = source[sourceIndex++];
		a[1] = (sourceIndex < sourceLength) ? source[sourceIndex++] : 0;
		a[2] = (sourceIndex < sourceLength) ? source[sourceIndex++] : 0;
		
		b[0] = (a[0] & 0xFC) >> 2; 
		b[1] = ((a[0] & 0x03) << 4) | ((a[1] & 0xF0) >> 4);
		b[2] = ((a[1] & 0x0F) << 2) | ((a[2] & 0xC0) >> 6);
		b[3] = (a[2] & 0x3F); 
		
		[result appendFormat:@"%c%c%c%c", table[b[0]], table[b[1]], table[b[2]], table[b[3]]]; 
	}
	
	// Padding
	int padding = 3 - (sourceLength % 3);
	if (padding != 0) {
		NSString *replacementString = (padding == 1) ? @"=" : @"==";
		NSRange replacementRange = NSMakeRange([result length] - padding, padding);
		[result replaceCharactersInRange:replacementRange withString:replacementString];
	}
	
	return result;
}

@end
