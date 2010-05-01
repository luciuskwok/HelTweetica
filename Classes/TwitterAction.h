//
//  TwitterConnection.h
//  HelTweetica
//
//  Created by Lucius Kwok on 4/25/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TwitterConnectionDelegate;

@interface TwitterAction : NSObject {
	NSString *consumerToken;
	NSString *consumerSecret;
	NSString *twitterMethod;
	NSDictionary *parameters;

	NSURLConnection *connection;
	NSMutableData *receivedData;
	NSInteger statusCode;
	BOOL isLoading;
	
	id completionTarget;
	SEL completionAction;
	id <TwitterConnectionDelegate> delegate;
}

@property (nonatomic, retain) NSString *consumerToken;
@property (nonatomic, retain) NSString *consumerSecret;
@property (nonatomic, retain) NSString *twitterMethod;
@property (nonatomic, retain) NSDictionary *parameters;

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (assign) NSInteger statusCode;
@property (assign) BOOL isLoading;

@property (assign) id completionTarget;
@property (assign) SEL completionAction;
@property (assign) id delegate;

- (void) start;
	// Subclasses should override -start to call the appropriate post or get request method.
- (void) startPostRequest;
- (void) startGetRequest;
- (void) cancel;

// Subclasses should override these methods:
- (void) parseReceivedData:(NSData*)data;

+ (NSURL*) URLWithBase: (NSString*) baseString query: (NSDictionary*) inParameters;

@end

@protocol TwitterConnectionDelegate <NSObject>
- (void) twitterActionDidFinishLoading:(TwitterAction*)aConnection;
- (void) twitterAction:(TwitterAction*)aConnection didFailWithError:(NSError*)error;
@end

