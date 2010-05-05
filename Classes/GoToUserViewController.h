//
//  GoToUserViewController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Twitter.h"

@protocol GoToUserViewControllerDelegate;


@interface GoToUserViewController : UITableViewController {
	Twitter *twitter;
	NSArray *users;
	id <GoToUserViewControllerDelegate> delegate;
}
@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) NSArray *users;
@property (nonatomic, assign) id delegate;

- (id)initWithTwitter:(Twitter*)aTwitter;

@end


@protocol GoToUserViewControllerDelegate <NSObject>
	- (void)showUserPage:(NSString*)screenName;
@end