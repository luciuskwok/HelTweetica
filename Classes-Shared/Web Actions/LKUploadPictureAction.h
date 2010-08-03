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
	NSString *username;
	NSString *password;
	NSData *media;
	NSString *fileType;
}
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, retain) NSData *media;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, assign) id<LKUploadPictureActionDelegate> delegate;

- (id)initWithPicture:(NSData *)picture fileExtension:(NSString *)ext;
- (void)startUpload;

@end


@protocol LKUploadPictureActionDelegate
- (void)action:(LKUploadPictureAction *)action didUploadPictureWithURL:(NSString *)url;
- (void)action:(LKUploadPictureAction *)action didFailWithError:(NSError *)error;
@end
