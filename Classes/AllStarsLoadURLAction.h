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
	NSString *identifier;
	NSInteger statusCode;
	BOOL isLoading;
	id <AllStarsLoadURLActionDelegate> delegate;
}
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) id delegate;

- (void)loadURL:(NSURL*)url;

@end



@protocol AllStarsLoadURLActionDelegate <NSObject>
- (void)loadURLAction:(AllStarsLoadURLAction*)action didLoadData:(NSData*)data;
- (void)loadURLAction:(AllStarsLoadURLAction*)action didFailWithError:(NSError*)error;
@end

