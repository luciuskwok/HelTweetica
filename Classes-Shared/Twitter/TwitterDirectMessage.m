//
//  TwitterDirectMessage.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/26/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "TwitterDirectMessage.h"


@implementation TwitterDirectMessage
@synthesize identifier, createdDate, receivedDate, senderIdentifier, senderScreenName, recipientIdentifier, recipientScreenName, text;


+ (NSArray *)databaseKeys {
	return [NSArray arrayWithObjects:@"identifier", @"createdDate", @"receivedDate", @"senderIdentifier", @"senderScreenName", @"recipientIdentifier", @"recipientScreenName", @"text", nil];
}

- (id)initWithDictionary:(NSDictionary *)d {
	self = [super init];
	if (self) {
		self.identifier = [d objectForKey:@"identifier"];
		self.createdDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[d objectForKey:@"createdDate"] doubleValue]];
		self.receivedDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[[d objectForKey:@"receivedDate"] doubleValue]];
		
		self.senderIdentifier = [d objectForKey:@"senderIdentifier"];
		self.senderScreenName = [d objectForKey:@"senderScreenName"];
		self.recipientIdentifier = [d objectForKey:@"recipientIdentifier"];
		self.recipientScreenName = [d objectForKey:@"recipientScreenName"];
		self.text = [d objectForKey:@"text"];
	}
	return self;
}

- (void)dealloc {
	[identifier release];
	[createdDate release];
	[receivedDate release];
	
	[senderIdentifier release];
	[senderScreenName release];
	[recipientIdentifier release];
	[recipientScreenName release];
	[text release];
	
	[super dealloc];
}

- (id)databaseValueForKey:(NSString *)key {
	return [self valueForKey:key];
}

- (NSString*) description {
	// description: for the debugger po command.
	NSMutableString *result = [NSMutableString string];
	if (senderScreenName != nil) 
		[result appendFormat:@"from: %@ ", senderScreenName];
	if (recipientScreenName != nil) 
		[result appendFormat:@"to: %@ ", recipientScreenName];
	if (text != nil) 
		[result appendString: text];
	return result;
}

- (NSUInteger) hash {
	// hash and isEqual: are used by NSSet to determine if an object is unique.
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

- (NSDate*) dateWithTwitterStatusString: (NSString*) string {
	// Twitter and Search use two different date formats, which differ by a comma at character 4.
	NSString *template = @"EEE MMM dd HH:mm:ss ZZ yyyy"; // Mon Jan 25 00:46:47 +0000 2010
	NSString *localeIdentifier = [NSLocale canonicalLocaleIdentifierFromString:@"en_US"];
	NSLocale *usLocale = [[[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier] autorelease];
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale: usLocale];
	[formatter setDateFormat:template];
	
	NSDate *result = [formatter dateFromString:string];
	return result;
}

- (NSNumber *)scanInt64FromString:(NSString *)string {
	SInt64 x = 0;
	[[NSScanner scannerWithString:string] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];
	return number;
}

// Given a key from the JSON data returned by the Twitter API, put the value in the appropriate ivar.
- (void) setValue:(id)value forTwitterKey:(NSString*)key {
	// String and number values
	if ([value isKindOfClass:[NSString class]]) {
		if ([key isEqualToString:@"id"]) {
			self.identifier = [self scanInt64FromString:value];
		} else if ([key isEqualToString:@"created_at"]) {
			self.createdDate = [self dateWithTwitterStatusString:value];
		} else if ([key isEqualToString:@"sender_id"]) {
			self.senderIdentifier = value;
		} else if ([key isEqualToString:@"sender_screen_name"]) {
			self.senderScreenName = value;
		} else if ([key isEqualToString:@"recipient_id"]) {
			self.recipientIdentifier = value;
		} else if ([key isEqualToString:@"recipient_screen_name"]) {
			self.recipientScreenName = value;
		} else if ([key isEqualToString:@"text"]) {
			self.text = value;
		}
	}
	
	// receivedDate is set by action.
}
@end
