//
//  NSDate+RelativeDate.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/29/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "NSDate+RelativeDate.h"


@implementation NSDate (RelativeDate)

- (NSString *)relativeDateSinceNow {
	NSString *result = nil;
	NSTimeInterval timeSince = -[self timeIntervalSinceNow] / 60.0 ; // in minutes
	if (timeSince < 48.0 * 60.0) { // If under 48 hours, report relative time
		int value;
		NSString *units;
		if (timeSince <= 1.5) { // report in seconds
			value = floor (timeSince * 60.0);
			units = @"second";
		} else if (timeSince < 90.0) { // report in minutes
			value = floor (timeSince);
			units = @"minute";
		} else { // report in hours
			value = floor (timeSince / 60.0);
			units = @"hour";
		}
		if (value == 1) {
			result = [NSString stringWithFormat:@"1 %@ ago", units];
		} else {
			result = [NSString stringWithFormat:@"%d %@s ago", value, units];
		}
	} else { // 48 hours or more, display the date
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		result = [dateFormatter stringFromDate:self];
	}
	return result;
}

@end
