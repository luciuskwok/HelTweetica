//
//  TwitterTimelineParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 3/30/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterAtomParser.h"

@interface TwitterAtomParser (PrivateMethods)
- (void) parseTitle;
- (void) parseContent;
- (void) parseDate;
@end


@implementation TwitterAtomParser
@synthesize tweets, currentMessage, currentKey, currentText, directMessage, receivedTimestamp;

- (void) dealloc {
	[interestingKeys release];
	[tweets release];
	[currentMessage release];
	[currentKey release];
	[currentText release];
	[receivedTimestamp release];
	[super dealloc];
}

- (id) init {
	if (self = [super init]) {
		interestingKeys = [[NSSet alloc] initWithObjects: @"id", @"title", @"content", @"published", nil];
	}
	return self;
}

- (NSArray*) parseData: (NSData*) xmlData {
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
	parser.delegate = self;
	self.tweets = [NSMutableArray array];
	[parser parse];
	[parser release];
	return self.tweets;
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
	NSLog (@"XML parser error %@", parseError);
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	
	if ([elementName isEqualToString:@"entry"]) {
		self.currentMessage = [[[TwitterStatusUpdate alloc] init] autorelease];
		currentMessage.direct = directMessage;
		if (receivedTimestamp != nil)
			currentMessage.receivedDate = receivedTimestamp;
	} else if ([elementName isEqualToString:@"link"]) {
		NSString *type = [attributeDict objectForKey:@"type"];
		NSString *href = [attributeDict objectForKey:@"href"];
		if ([type hasPrefix:@"image"])
			self.currentMessage.avatar = href;
	} else if ([interestingKeys containsObject:elementName]) {
		self.currentText = [[[NSMutableString alloc] init] autorelease];
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	[currentText appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	if ([elementName isEqualToString:@"entry"]) {
		[self.tweets addObject: self.currentMessage];
		self.currentMessage = nil;
	} else if ([interestingKeys containsObject:elementName]) {
		if (self.currentText != nil) {
			if ([elementName isEqualToString:@"id"]) {
				// For the id, extract the last path component from the URL.
				NSScanner *scanner = [NSScanner scannerWithString:[currentText lastPathComponent]];
				SInt64 identifierInt64 = 0;
				[scanner scanLongLong: &identifierInt64];
				self.currentMessage.identifier = [NSNumber numberWithLongLong: identifierInt64];
			} else if ([elementName isEqualToString:@"title"]) {
				[self parseTitle];
			} else if ([elementName isEqualToString:@"content"]) {
				[self parseContent];
			} else if ([elementName isEqualToString:@"published"]) {
				[self parseDate];
			}
		}
		self.currentText = nil;
	}
}

- (void) parseTitle {
	if (directMessage == YES) {
		// For direct messages, extract the author's username from the title
		NSArray *words = [self.currentText componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
		if (words.count > 2) {
			self.currentMessage.userScreenName = [words objectAtIndex:2]; // from user is always third word
		}
	}
}

- (void) parseContent {
	if (directMessage == YES) {
		// For direct messages, the entire content is the message
		self.currentMessage.content = currentText;
	} else {
		NSRange range = [currentText rangeOfString: @": "];
		if (range.location != NSNotFound) {
			self.currentMessage.userScreenName = [currentText substringToIndex: range.location];
			self.currentMessage.content = [currentText substringFromIndex:range.location + range.length];
		} else {
			self.currentMessage.content = currentText;
		}
	}
}

- (void) parseDate {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"]; // 2010-04-01T04:32:26+00:00
	self.currentMessage.createdDate = [formatter dateFromString:currentText];
	[formatter release];
}

@end
