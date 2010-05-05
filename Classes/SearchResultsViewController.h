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

}
- (id)initWithQuery:(NSString*)query;
- (NSString *)htmlSafeString:(NSString *)string;

@end
