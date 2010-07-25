//
//  AllStarsLoadURLAction.h
//  HelTweetica
//
//  Created by Lucius Kwok on 7/24/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol AllStarsLoadURLActionDelegate;


@interface AllStarsLoadURLAction : NSObject {
	NSURLConnection *connection;
	NSMutableData *receivedData;
	NSInteger statusCode;
	BOOL isLoading;
	id <AllStarsLoadURLActionDelegate> delegate;
}

@property (nonatomic, assign) id delegate;

@end

- (void)loadURL:(NSURL*)url;


@protocol AllStarsLoadURLActionDelegate
- (void)loadURLAction:(AllStarsLoadURLAction*)action didLoadData:(NSData*)data;
- (void)loadURLAction:(AllStarsLoadURLAction*)action didFailWithError:(NSError*)error;
@end

