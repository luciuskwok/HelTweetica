//
//  LKUploadPictureAction.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 8/1/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKLoadURLAction.h"
@protocol LKUploadPictureActionDelegate;


@interface LKUploadPictureAction : LKLoadURLAction {
	NSData *media;
	NSString *username;
	NSString *password;
}
@property (nonatomic, retain) NSData *media;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, assign) id<LKUploadPictureActionDelegate> delegate;

- (void)startUpload;

@end


@protocol LKUploadPictureActionDelegate
- (void)action:(LKUploadPictureAction *)action didUploadPictureWithURL:(NSString *)url;
- (void)action:(LKUploadPictureAction *)action didFailWithErrorCode:(int)code description:(NSString *)description;
@end
