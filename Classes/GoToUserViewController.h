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


@interface GoToUserViewController : UITableViewController <UISearchBarDelegate, UISearchDisplayDelegate> {
	Twitter *twitter;
	NSArray *users;
	UISearchDisplayController *searchController;
	id <GoToUserViewControllerDelegate> delegate;
}
@property (nonatomic, retain) Twitter *twitter;
@property (nonatomic, retain) NSArray *users;
@property (nonatomic, retain) UISearchDisplayController *searchController;
@property (nonatomic, assign) id delegate;

- (id)initWithTwitter:(Twitter*)aTwitter;

@end


@protocol GoToUserViewControllerDelegate <NSObject>
	- (void)showUserPage:(NSString*)screenName;
@end