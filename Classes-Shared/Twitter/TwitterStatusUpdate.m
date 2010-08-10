//
//  Message.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/1/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterStatusUpdate.h"
#import "NSDate+RelativeDate.h"
#import "NSString+HTMLFormatted.h"


@implementation TwitterStatusUpdate
@synthesize identifier, userIdentifier, userScreenName;
@synthesize inReplyToStatusIdentifier, inReplyToUserIdentifier, inReplyToScreenName;
@synthesize profileImageURL, text, source, retweetedStatusIdentifier;
@synthesize longitude, latitude;
@synthesize createdDate, receivedDate;
@synthesize locked;

+ (NSArray *)databaseKeys {
	return [NSArray arrayWithObjects:@"identifier", @"createdDate", @"receivedDate", @"userIdentifier", @"userScreenName", 
			@"profileImageURL", @"inReplyToStatusIdentifier", @"inReplyToUserIdentifier", @"inReplyToScreenName", @"retweetedStatusIdentifier", @"longitude", @"latitude", 
			@"text", @"source", @"locked", nil];
}

- (id)initWithDictionary:(NSDictionary *)d {
	self = [super init];
	if (self) {
		self.identifier = [d objectForKey:@"identifier"];
		self.createdDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[d objectForKey:@"createdDate"] doubleValue]];
		self.receivedDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[d objectForKey:@"receivedDate"] doubleValue]];

		self.userIdentifier = [d objectForKey:@"userIdentifier"];
		self.userScreenName = [d objectForKey:@"userScreenName"];
		self.profileImageURL = [d objectForKey:@"profileImageURL"];

		self.inReplyToStatusIdentifier = [d objectForKey:@"inReplyToStatusIdentifier"];
		self.inReplyToUserIdentifier = [d objectForKey:@"inReplyToUserIdentifier"];
		self.inReplyToScreenName = [d objectForKey:@"inReplyToScreenName"];
		self.retweetedStatusIdentifier = [d objectForKey:@"retweetedStatusIdentifier"];

		self.longitude = [d objectForKey:@"longitude"];
		self.latitude = [d objectForKey:@"latitude"];

		self.text = [d objectForKey:@"text"];
		self.source = [d objectForKey:@"source"];
		self.locked = [[d objectForKey:@"locked"] boolValue];
	}
	return self;
}

- (void) dealloc {
	[identifier release];
	[createdDate release];
	[receivedDate release];

	[userIdentifier release];
	[userScreenName release];
	[profileImageURL release];

	[inReplyToStatusIdentifier release];
	[inReplyToUserIdentifier release];
	[inReplyToScreenName release];
	[retweetedStatusIdentifier release];
	
	[longitude release];
	[latitude release];
	
	[text release];
	[source release];
	
	[super dealloc];
}

- (id)databaseValueForKey:(NSString *)key {
	if ([key isEqualToString:@"locked"]) {
		return [NSNumber numberWithBool:self.locked];
	}
	return [self valueForKey:key];
}

// description: for the debugger po command.
- (NSString*) description {
	NSMutableString *result = [NSMutableString string];
	if (userScreenName != nil) 
		[result appendFormat:@"%@: ", userScreenName];
	if (text != nil) 
		[result appendString: text];
	return result;
}

// hash and isEqual: are used by NSSet to determine if an object is unique.
- (NSUInteger) hash {
	return [identifier hash];
}

- (BOOL) isEqual:(id)object {
	BOOL result = NO;
	if ([object respondsToSelector:@selector(identifier)]) {
		result = [self.identifier isEqual: [object identifier]];
	}
	return result;
}

#pragma mark Twitter API

- (NSNumber *)scanInt64FromString:(NSString *)string {
	SInt64 x = 0;
	[[NSScanner scannerWithString:string] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];
	return number;
}

- (NSNumber *)scanDoubleFromString:(NSString *)string {
	double x = 0;
	[[NSScanner scannerWithString:string] scanDouble: &x];
	NSNumber *number = [NSNumber numberWithDouble: x];
	return number;
}

// Given a key from the JSON data returned by the Twitter API, put the value in the appropriate ivar.
- (void) setValue:(id)value forTwitterKey:(NSString*)key {
	// String and number values
	if ([value isKindOfClass:[NSString class]]) {
		if ([key isEqualToString:@"in_reply_to_screen_name"]) {
			self.inReplyToScreenName = value;
		} else if ([key isEqualToString:@"source"]) {
			self.source = value;
		} else if ([key isEqualToString:@"text"]) {
			self.text = value;
		} else if ([key isEqualToString:@"id"]) {
			self.identifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"in_reply_to_status_id"]) {
			self.inReplyToStatusIdentifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"in_reply_to_user_id"]) {
			self.inReplyToUserIdentifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"created_at"]) {
			self.createdDate = [value twitterDate];
		} else if ([key isEqualToString:@"coordinates"]) {
			if (latitude == nil) {
				self.latitude = [self scanDoubleFromString:value];
			} else {
				self.longitude = [self scanDoubleFromString:value];
			}
		}
	}
	
	// Other values are usually taken from elsewhere, for example: the user dictionary embedded in the status update in timelines.
}

#pragma mark HTML 

- (NSString *)stringForURLWithPrefix:(NSString *)prefix {
	static NSCharacterSet *urlSet = nil;
	if (urlSet == nil) {
		urlSet = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+_-:/."] retain];
	}
	
	NSString *urlString = nil;
	NSScanner *scanner = [NSScanner scannerWithString:text];
	[scanner setCharactersToBeSkipped:nil];
	
	while ([scanner isAtEnd] == NO) {
		[scanner scanUpToString:prefix intoString:nil];
		if ([scanner scanCharactersFromSet:urlSet intoString:&urlString]) {
			if ([urlString hasSuffix:@"."])
				urlString = [urlString substringToIndex:urlString.length - 1];
			return urlString;
		}
	}
	
	return nil;
}

- (NSDictionary *)htmlSubstitutions {
	
	// Set up dictionary with variables to substitute
	NSMutableDictionary *substitutions = [NSMutableDictionary dictionary];
	if (self.userScreenName)
		[substitutions setObject:self.userScreenName forKey:@"screenName"];
	if (self.identifier)
		[substitutions setObject:[self.identifier stringValue] forKey:@"messageIdentifier"];
	if (self.profileImageURL)
		[substitutions setObject:self.profileImageURL forKey:@"profileImageURL"];
	if (self.text)
		[substitutions setObject:[self.text HTMLFormatted] forKey:@"content"];
	if (self.createdDate) 
		[substitutions setObject:[self.createdDate relativeDateSinceNow] forKey:@"createdDate"];
	if (self.source) 
		[substitutions setObject:self.source forKey:@"via"];
	if (self.inReplyToScreenName) 
		[substitutions setObject:self.inReplyToScreenName forKey:@"inReplyToScreenName"];
	if ([self isLocked])
		[substitutions setObject:@"<img src='lock.png'>" forKey:@"lockIcon"];
	if (self.longitude && self.latitude) {
		NSString *geoHTML = [NSString stringWithFormat:@"<a href='http://maps.google.com/maps?q=%1.9f,%1.9f'><img src='geotag.png'></a>", [latitude doubleValue], [longitude doubleValue]];
		[substitutions setObject:geoHTML forKey:@"geotagIcon"];
	}

	
	// Find image previews.
	NSString *searchResults;
	NSString *imageURL = nil;
	NSString *imagePreviewURL = nil;
	
	// TwitPic
	searchResults = [self stringForURLWithPrefix:@"http://twitpic.com/"];
	if (searchResults.length > 19) {
		imageURL = searchResults;
		imagePreviewURL = [NSString stringWithFormat:@"http://twitpic.com/show/thumb/%@", [imageURL lastPathComponent]];
	}
	
	// yFrog
	searchResults = [self stringForURLWithPrefix:@"http://yfrog.com/"];
	if (searchResults.length > 17) {
		imageURL = searchResults;
		if ([imageURL hasSuffix:@".jpg"]) {
			imagePreviewURL = [imageURL stringByReplacingOccurrencesOfString:@".jpg" withString:@".th.jpg"];
		} else {
			imagePreviewURL = [imageURL stringByAppendingString:@".th.jpg"];
		}

	}
	
	// Moby Picture
	searchResults = [self stringForURLWithPrefix:@"http://moby.to/"];
	if (searchResults.length > 15) {
		imageURL = searchResults;
		imagePreviewURL = [imageURL stringByAppendingString:@":thumb"];
	}
	
	// Tweet Photo  http://pic.gd/0f53e6
	searchResults = [self stringForURLWithPrefix:@"http://pic.gd/"]; 
	if (searchResults == nil)
		searchResults = [self stringForURLWithPrefix:@"http://tweetphoto.com/"]; 
	if (searchResults.length > 14) {
		imageURL = searchResults;
		imagePreviewURL = [@"http://TweetPhotoAPI.com/api/TPAPI.svc/imagefromurl?size=small&url=" stringByAppendingString:imageURL];
	}
	
	// img.ly
	searchResults = [self stringForURLWithPrefix:@"http://img.ly/"]; 
	if (searchResults.length > 14) {
		imageURL = searchResults;
		NSString *imageIdentifier = [imageURL lastPathComponent];
		NSString *imageBase = [imageURL stringByDeletingLastPathComponent];
		imagePreviewURL = [imageBase stringByAppendingPathComponent:@"show/thumb"];
		imagePreviewURL = [imagePreviewURL stringByAppendingPathComponent:imageIdentifier];
	}
	
	// Add image URLs.
	if (imagePreviewURL != nil) {
		[substitutions setObject:imageURL forKey:@"imageURL"];
		[substitutions setObject:imagePreviewURL forKey:@"imagePreviewURL"];
	}
	
	return substitutions;
}

@end
