//
//  NSDate+RelativeDate.h
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/29/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSDate (RelativeDate)
- (NSString *)relativeDateSinceNow;
+(NSDate *)dateWithTwitterString:(NSString *)string;
@end
