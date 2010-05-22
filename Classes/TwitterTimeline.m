//
//  TwitterTimeline.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TwitterTimeline.h"
#import "TwitterLoadTimelineAction.h"


@implementation TwitterTimeline
@synthesize messages, gaps, loadAction;

- (id)init {
	self = [super init];
	if (self) {
		self.messages = [NSMutableArray array];
		self.gaps = [NSMutableArray array];
	}
	return self;
}

- (void)dealloc {
	[messages release];
	[gaps release];
	[loadAction release];
	[super dealloc];
}

#pragma mark NSCoding

- (NSMutableArray*) mutableArrayForKey:(NSString *)key coder:(NSCoder *)decoder {
	NSData *data = [decoder decodeObjectForKey:key];
	NSMutableArray *array;
	if (data && [data isKindOfClass:[NSData class]]) {
		array = [NSMutableArray arrayWithArray: [NSKeyedUnarchiver unarchiveObjectWithData:data]];
	} else {
		array = [NSMutableArray array];
	}
	return array;
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.messages = [self mutableArrayForKey:@"messages" coder:decoder];
		self.gaps = [self mutableArrayForKey:@"gaps" coder:decoder];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:messages] forKey: @"messages"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:gaps] forKey: @"gaps"];
}

#pragma mark Synchronize

- (void)removeMessageWithIdentifier:(NSNumber*)anIdentifier {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", anIdentifier];
	NSMutableArray *filteredArray = [NSMutableArray arrayWithArray: self.messages];
	[filteredArray filterUsingPredicate:predicate];
	[self.messages removeObjectsInArray:filteredArray];
}

- (void)limitTimelineLength:(int)maxLength {
	// Limit the length of the timeline
	if (messages.count > maxLength) {
		NSRange removalRange = NSMakeRange(maxLength, messages.count - maxLength);
		[messages removeObjectsInRange:removalRange];
	}
}	


@end
