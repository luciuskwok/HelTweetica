//
//  TwitterAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

enum TwitterActionErrorCode {
	TwitterActionErrorCodeDirectMessageFailedNoFollow = 0	
} TwitterActionErrorCode;

@protocol TwitterActionDelegate;
@class HelTweeticaAppDelegate;

@interface TwitterAction : NSObject {
	NSString *consumerToken;
	NSString *consumerSecret;
	NSString *twitterMethod;
	NSMutableDictionary *parameters;
	NSString *countKey;

	NSURLConnection *connection;
	NSMutableData *receivedData;
	NSInteger statusCode;
	BOOL isLoading;
	NSError *twitterAPIError;
	
	id completionTarget;
	SEL completionAction;
	id delegate;
	
	HelTweeticaAppDelegate *appDelegate;
}

@property (nonatomic, retain) NSString *consumerToken;
@property (nonatomic, retain) NSString *consumerSecret;
@property (nonatomic, retain) NSString *twitterMethod;
@property (nonatomic, retain) NSMutableDictionary *parameters;
@property (nonatomic, retain) NSString *countKey;

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (assign) NSInteger statusCode;
@property (assign) BOOL isLoading;
@property (nonatomic, retain) NSError *twitterAPIError;

@property (assign) id completionTarget;
@property (assign) SEL completionAction;
@property (assign) id <TwitterActionDelegate> delegate; // delegate is retained while a NSURLConnection is active, and released if it finished loading or failed with an error.

- (void) start;
	// Subclasses should override -start to call the appropriate post or get request method.
- (void) startURLRequest:(NSMutableURLRequest*)request;
- (void) startPostRequest;
- (void) startGetRequest;
- (void) cancel;

// Subclasses can override setCount: if the parameter is not named "count".
- (void)setCount:(int)count;

// Subclasses should override these methods:
- (void) parseReceivedData:(NSData*)data;

+ (NSString*) URLEncodeString: (NSString*) aString;
+ (NSURL*) URLWithBase: (NSString*) baseString query: (NSDictionary*) inParameters;

@end

@protocol TwitterActionDelegate <NSObject>
@optional
- (void) twitterActionDidFinishLoading:(TwitterAction*)aConnection;
- (void) twitterAction:(TwitterAction*)aConnection didFailWithError:(NSError*)error;
@end

