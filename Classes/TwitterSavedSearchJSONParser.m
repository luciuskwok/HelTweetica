//
//  TwitterSavedSearchJSONParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/11/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterSavedSearchJSONParser.h"
#import "LKJSONParser.h"


@implementation TwitterSavedSearchJSONParser
@synthesize key;


- (id) init {
	if (self = [super init]) {
		queries = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	[queries release];
	[key release];
	[super dealloc];
}

- (NSArray*) queriesWithJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
	return [[queries retain] autorelease];
}

- (void) parser:(LKJSONParser*)parser foundKey:(NSString*)aKey {
	self.key = aKey;
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	if ([key isEqualToString:@"query"]) {
		[queries addObject:value];
	}
}

@end
