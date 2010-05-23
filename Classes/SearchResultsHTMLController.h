//
//  SearchResultsHTMLController.h
//  HelTweetica
//
//  Created by Lucius Kwok on 5/23/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TimelineHTMLController.h"


@interface SearchResultsHTMLController : TimelineHTMLController {

}

- (id)initWithQuery:(NSString*)aQuery;
- (NSString *)htmlSafeString:(NSString *)string;

@end
