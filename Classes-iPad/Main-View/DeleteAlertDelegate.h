//
//  DeleteAlertDelegate.h
//  HelTweetica-iPad
//
//  Created by Lucius Kwok on 8/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TimelineHTMLController.h"


@interface DeleteAlertDelegate : NSObject {
	NSNumber *identifier;
	TimelineHTMLController *htmlController;
	id delegate;
}
@property (nonatomic, retain) NSNumber *identifier;
@property (nonatomic, retain) TimelineHTMLController *htmlController;
@property (nonatomic, assign) id <UIAlertViewDelegate> delegate;

- (UIAlertView *)showAlert;


@end
