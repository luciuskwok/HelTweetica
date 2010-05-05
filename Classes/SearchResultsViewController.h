//
//  SearchResultsViewController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/5/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TimelineViewController.h"


@interface SearchResultsViewController : TimelineViewController {
	IBOutlet UIBarButtonItem *saveButton;
	NSString *query;
}
@property (nonatomic, retain) UIBarButtonItem *saveButton;
@property (nonatomic, retain) NSString *query;

- (id)initWithQuery:(NSString*)aQuery;
- (NSString *)htmlSafeString:(NSString *)string;

- (IBAction)saveSearch:(id)sender;

@end
