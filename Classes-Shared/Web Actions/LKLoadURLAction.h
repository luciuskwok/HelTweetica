//
//  LKLoadURLAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 7/24/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol LKLoadURLActionDelegate;


@interface LKLoadURLAction : NSObject {
	NSURL *url;
	NSURLConnection *connection;
	NSMutableData *receivedData;
	NSString *identifier;
	NSInteger statusCode;
	BOOL isLoading;
	id delegate;
}
@property (nonatomic, retain) NSURL *url;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) id<LKLoadURLActionDelegate> delegate;

- (id)initWithURL:(NSURL *)anURL;
- (void)start;
- (void)cancel;
- (void)dataFinishedLoading:(NSData *)data;
- (void)failedWithError:(NSError *)error;

@end


@protocol LKLoadURLActionDelegate <NSObject>
- (void)loadURLAction:(LKLoadURLAction*)action didLoadData:(NSData*)data;
- (void)loadURLAction:(LKLoadURLAction*)action didFailWithError:(NSError*)error;
@end

