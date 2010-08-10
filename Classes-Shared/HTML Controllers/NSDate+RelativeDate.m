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
	static NSDateFormatter *sRelativeDateFormatter = nil;
	if (sRelativeDateFormatter == nil) {
		sRelativeDateFormatter = [[NSDateFormatter alloc] init];
		[sRelativeDateFormatter setTimeStyle:NSDateFormatterNoStyle];
		[sRelativeDateFormatter setDateStyle:NSDateFormatterShortStyle];
	}
	
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
		result = [sRelativeDateFormatter stringFromDate:self];
	}
	return result;
}

+(NSDate *)dateWithTwitterString:(NSString *)string {
	// Date format for search.twitter.com and api.twitter.com
	static NSDateFormatter *sSearchDateFormatter = nil;
	static NSDateFormatter *sAPIDateFormatter = nil;
	if (sSearchDateFormatter == nil || sAPIDateFormatter == nil) {
		NSLocale *usLocale = [[[NSLocale alloc] initWithLocaleIdentifier:[NSLocale canonicalLocaleIdentifierFromString:@"en_US"]] autorelease];
		
		// Mon, 25 Jan 2010 00:46:47 +0000 
		sSearchDateFormatter = [[NSDateFormatter alloc] init];
		[sSearchDateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZ"]; 
		[sSearchDateFormatter setLocale: usLocale];
		
		// Mon Jan 25 00:46:47 +0000 2010
		sAPIDateFormatter = [[NSDateFormatter alloc] init];
		[sAPIDateFormatter setDateFormat:@"EEE MMM dd HH:mm:ss ZZ yyyy"]; 
		[sAPIDateFormatter setLocale: usLocale];
	}
	
	// Twitter and Search use two different date formats, which differ by a comma at character 4.
	NSDateFormatter *formatter;
	if ([string characterAtIndex:3] == ',') {
		formatter = sSearchDateFormatter;
	} else {
		formatter = sAPIDateFormatter;
	}
	
	return [formatter dateFromString:string];
}

@end
