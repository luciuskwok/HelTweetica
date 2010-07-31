//
//  LKShrinkURLAction.h
//  HelTweetica-iPad
//
//  Created by Lucius Kwok on 7/31/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKLoadURLAction.h"
@protocol LKShrinkURLActionDelegate;


@interface LKShrinkURLAction : LKLoadURLAction {
}
@property (nonatomic, assign) id<LKShrinkURLActionDelegate> delegate;
+ (NSSet *)actionsToShrinkURLsInString:(NSString *)string;
- (void)load;
@end


@protocol LKShrinkURLActionDelegate
- (void)shrinkURLAction:(LKShrinkURLAction *)anAction replacedLongURL:(NSString *)longURL withShortURL:(NSString *)shortURL;
- (void)shrinkURLAction:(LKShrinkURLAction*)anAction didFailWithError:(NSError*)error;
@end


