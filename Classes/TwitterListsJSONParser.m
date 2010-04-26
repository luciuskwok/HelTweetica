//
//  TwitterListsJSONParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/9/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterListsJSONParser.h"
#import "TwitterList.h"


@implementation TwitterListsJSONParser
@synthesize lists, currentList, keyPath;

+ (void) runTest {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"json"];
	NSError *error = nil;
	NSData *testJSON = [NSData dataWithContentsOfFile:path options:0 error:&error];
	TwitterListsJSONParser *parser = [[TwitterListsJSONParser alloc] init];
	NSArray *lists = [parser listsWithJSONData:testJSON];
	NSLog (@"lists count=%d", lists.count);
	[parser release];
}

#pragma mark -

- (id) init {
	if (self = [super init]) {
		lists = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	[lists release];
	[currentList release];
	[keyPath release];
	[super dealloc];
}

- (NSArray*) listsWithJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
	return [[lists retain] autorelease];
}

#pragma mark -
// LKJSONParser delegate methods

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	if (keyPath == nil) {
		self.keyPath = @"/";
	} else {
		self.keyPath = [keyPath stringByAppendingString:@"/"];
	}
	
	if ([keyPath isEqualToString:@"/lists/"]) {
		self.currentList = [[[TwitterList alloc] init] autorelease];
	}
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath substringToIndex: keyPath.length - 1];
	} else {
		self.keyPath = [keyPath stringByDeletingLastPathComponent];
	}

	if ([keyPath isEqualToString:@"/lists"]) {
		if (currentList != nil) {
			[lists addObject: currentList];
			self.currentList = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
}

- (void) parserFoundNullValue:(LKJSONParser*)parser {
}

- (void) parser:(LKJSONParser*)parser foundBoolValue:(BOOL)value {
	//NSLog (@"%@ = %d", keyPath, value);
}

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	SInt64 x = 0;
	[[NSScanner scannerWithString:value] scanLongLong: &x];
	NSNumber *number = [NSNumber numberWithLongLong: x];

	if ([keyPath isEqualToString:@"/lists/member_count"]) {
		currentList.memberCount = number;
	} else if ([keyPath isEqualToString:@"/lists/id"]) {
		currentList.identifier = number;
	} 
	
	//NSLog (@"%@ = %@", keyPath, value);
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([keyPath isEqualToString:@"/lists/description"]) {
		currentList.description = value;
	} else if ([keyPath isEqualToString:@"/lists/name"]) {
		currentList.name = value;
	} else if ([keyPath isEqualToString:@"/lists/full_name"]) {
		currentList.fullName = value;
	} else if ([keyPath isEqualToString:@"/lists/slug"]) {
		currentList.slug = value;
	}
	
	//NSLog (@"%@ = %@", keyPath, value);
}

- (void) parser:(LKJSONParser*)parser foundKey:(NSString*)key {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath stringByAppendingPathComponent:key];
	} else {
		NSString *base = [keyPath stringByDeletingLastPathComponent];
		self.keyPath = [base stringByAppendingPathComponent:key];
	}
}

@end
