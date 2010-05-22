//
//  LKJSONParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/8/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


/* Terminology:
 JSON uses slightly different and confusing terms for the same things in Cocoa.
 A JSON object is a NSDictionary.
 A JSON array is a NSArray.
 A JSON value is a NSObject, which can be a string, number, NSDictionary, NSArray, true, false, or null.
 A JSON string is a NSString and is always contained within double quotes. "string".
 A JSON number is a NSNumber and is never in double quotes. 1.234e10.
 */

#import "LKJSONParser.h"

@interface LKJSONParser (PrivateMethods)

- (void) parseValue;
- (NSString*) parseStringValue;
- (void) parseNumericValue;
- (void) parseArray;
- (void) parseDictionary;
- (void) parseKeyValuePair;
- (void) skipWhitespaceAndNewlines;

- (void) beginArray;
- (void) endArray;
- (void) beginDictionary;
- (void) endDictionary;
- (void) foundNullValue;
- (void) foundBoolValue:(BOOL)value;
- (void) foundNumberValue:(NSString*)value;
- (void) foundStringValue:(NSString*)value;
- (void) foundKey:(NSString*)key;
- (NSString*) unescapeJSONString:(NSString*)jsonString;
@end

@implementation LKJSONParser
@synthesize keyPath, delegate;

- (id) initWithData:(NSData*)jsonData {
	if (self = [super init]) {
		jsonText = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
	}
	return self;
}

- (void) dealloc {
	[jsonText release];
	[keyPath release];
	[super dealloc];
}

#pragma mark -

- (void) parse {
	jsonOffset = 0;
	[self parseValue];
}

- (void) parseValue {
	[self skipWhitespaceAndNewlines];
	if (jsonOffset >= [jsonText length]) return;
	
	NSString *value;
	unichar c = [jsonText characterAtIndex:jsonOffset];
	switch (c) {
		case 0x5B: // '[' begin array
			[self beginArray];
			jsonOffset++;
			[self parseArray];
			break;
		case 0x7B: // '{' begin dictionary
			[self beginDictionary];
			jsonOffset++;
			[self parseDictionary];
			break;
		case 0x22: // double-quote means it's a string
			value = [self parseStringValue];
			[self foundStringValue:value];
			break;
		default:
			[self parseNumericValue];
			break;
	}
}

- (NSString*) parseStringValue {
	// Skip the initial double-quote
	jsonOffset++;
	if (jsonOffset >= [jsonText length]) return nil;
	
	// Determine the length of the string
	unsigned int textLength = [jsonText length];
	NSRange found;
	found.location = jsonOffset;
	unichar c = [jsonText characterAtIndex:jsonOffset];
	while ((jsonOffset < textLength) && (c != 0x22)) {
		jsonOffset++;
		if (c == '\\') jsonOffset++; // Ignore escaped chars
		c = [jsonText characterAtIndex:jsonOffset];
	}
	found.length = jsonOffset - found.location;
	jsonOffset++;
	
	// Extract and unescape the string
	return [self unescapeJSONString: [jsonText substringWithRange:found]];
}

- (void) parseNumericValue {
	if (jsonOffset >= [jsonText length]) return;
	
	static NSCharacterSet *sSearchSet = nil;
	if (sSearchSet == nil) {
		sSearchSet = [[NSCharacterSet characterSetWithCharactersInString:@",}] \n\r\t"] retain];
	}
	
	NSRange found;
	unichar c = [jsonText characterAtIndex:jsonOffset];
	switch (c) {
		case 'n': // null
			[self foundNullValue];
			jsonOffset += 4;
			break;
		case 't': // true
			[self foundBoolValue: YES];
			jsonOffset += 4;
			break;
		case 'f': // false
			[self foundBoolValue: NO];
			jsonOffset += 5;
			break;
		default: // numeric value
			found = [jsonText rangeOfCharacterFromSet:sSearchSet options:0 range:NSMakeRange(jsonOffset, [jsonText length] - jsonOffset)];
			if (found.location != NSNotFound) {
				NSString *valueString = [jsonText substringWithRange:NSMakeRange(jsonOffset, found.location - jsonOffset)];
				[self foundNumberValue:valueString];
				jsonOffset = found.location;
			}
			break;
	}
}

- (void) parseArray {
	unsigned int textLength = [jsonText length];
	while (jsonOffset < textLength) {
		// Check for end of array
		[self skipWhitespaceAndNewlines];
		if (jsonOffset >= textLength) return;
		
		unichar c = [jsonText characterAtIndex:jsonOffset];
		if (c == 0x5D) { // 0x5D = ']' end array
			[self endArray];
			jsonOffset++;
			return; 
		}
		if (c == 0x2C) { // 0x2C = comma. Which is ignored in the parser. 
			//[self beginNextItem];
			jsonOffset++; 
		}
		
		[self parseValue];
	}	
}

- (void) parseDictionary {
	unsigned int textLength = [jsonText length];
	while (jsonOffset < textLength) {
		// Check for end of array
		[self skipWhitespaceAndNewlines];
		if (jsonOffset >= textLength) return;
		
		switch ([jsonText characterAtIndex:jsonOffset]) {
			case 0x7D: // 0x7D = '}' end dictionary
				[self endDictionary];
				jsonOffset++;
				return; 
			case 0x22: // double-quote means it's a string
				[self parseKeyValuePair];
				break;
			case 0x2C:  // 0x2C = comma. Which is ignored in the parser. 
			default:
				jsonOffset++; // Skip spurious character
				break;
		}
	}	
}

- (void) parseKeyValuePair {
	unsigned int textLength = [jsonText length];
	NSString *key = [self parseStringValue];

	// Find the colon separator
	while (jsonOffset < textLength) {
		if ([jsonText characterAtIndex:jsonOffset] == ':') break;
		jsonOffset++;
	}
	jsonOffset++;
	if (jsonOffset >= textLength) return;
	
	[self foundKey:key];
	[self skipWhitespaceAndNewlines];
	[self parseValue];
}

- (void) skipWhitespaceAndNewlines {
	// Skip past whitespace
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	unsigned int textLength = [jsonText length];
	while (jsonOffset < textLength) {
		if ([whitespaceSet characterIsMember: [jsonText characterAtIndex:jsonOffset]] == NO)
			return;
		jsonOffset++;
	}
}

#pragma mark -

- (void) beginArray {
	if ([delegate respondsToSelector:@selector (parserDidBeginArray:)]) 
		[delegate parserDidBeginArray:self];
}

- (void) endArray {
	if ([delegate respondsToSelector:@selector (parserDidEndArray:)]) 
		[delegate parserDidEndArray:self];
}

- (void) beginDictionary {
	if (keyPath == nil) {
		self.keyPath = @"/";
	} else {
		if ([keyPath hasSuffix:@"/"] == NO)
			self.keyPath = [keyPath stringByAppendingString:@"/"];
	}
	
	if ([delegate respondsToSelector:@selector (parserDidBeginDictionary:)]) 
		[delegate parserDidBeginDictionary:self];
}

- (void) endDictionary {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath substringToIndex: keyPath.length - 1];
	} else {
		self.keyPath = [keyPath stringByDeletingLastPathComponent];
	}
	
	if ([delegate respondsToSelector:@selector (parserDidEndDictionary:)]) 
		[delegate parserDidEndDictionary:self];
}

- (void) foundNullValue {
	if ([delegate respondsToSelector:@selector (parserFoundNullValue:)]) 
		[delegate parserFoundNullValue:self];
}

- (void) foundBoolValue:(BOOL)value {
	if ([delegate respondsToSelector:@selector (parser:foundBoolValue:)]) 
		[delegate parser:self foundBoolValue:value];
}

- (void) foundNumberValue:(NSString*)value {
	if ([delegate respondsToSelector:@selector (parser:foundNumberValue:)]) 
		[delegate parser:self foundNumberValue:value];
}

- (void) foundStringValue:(NSString*)value {
	if ([delegate respondsToSelector:@selector (parser:foundStringValue:)]) 
		[delegate parser:self foundStringValue:value];
}

- (void) foundKey:(NSString*)key {
	if ([keyPath hasSuffix:@"/"]) {
		self.keyPath = [keyPath stringByAppendingPathComponent:key];
	} else {
		NSString *base = [keyPath stringByDeletingLastPathComponent];
		self.keyPath = [base stringByAppendingPathComponent:key];
	}

	if ([delegate respondsToSelector:@selector (parser:foundKey:)]) 
		[delegate parser:self foundKey:key];
}

#pragma mark -

- (NSString*) unescapeJSONString:(NSString*)jsonString {
	NSScanner *scanner = [NSScanner scannerWithString:jsonString];
	NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
	NSString *value;
	NSCharacterSet *matchSet = [NSCharacterSet characterSetWithCharactersInString:@"\\"]; // Match a single backslash char
	
	[scanner setCharactersToBeSkipped:nil];
	
	while ([scanner isAtEnd] == NO) {
		if ([scanner scanUpToCharactersFromSet:matchSet intoString:&value]) {
			[result appendString: value];
		}
		if ([scanner scanString:@"\\u" intoString:nil]) { 
			// Unicode char
			if (scanner.scanLocation + 4 <= jsonString.length) {
				NSString *hexString = [jsonString substringWithRange: NSMakeRange(scanner.scanLocation, 4)];
				NSScanner *hexScanner = [NSScanner scannerWithString:hexString];
				unsigned x = 0x20;
				if ([hexScanner scanHexInt:&x]) {
					unichar c = x;
					[result appendString:[NSString stringWithCharacters: &c length:1]];
				}
				scanner.scanLocation = scanner.scanLocation + 4;
			}
			
		} else if ([scanner scanString:@"\\\"" intoString:nil]) {
			[result appendString:@"\""];
		} else if ([scanner scanString:@"\\b" intoString:nil]) {
			[result appendString:@"\b"];
		} else if ([scanner scanString:@"\\f" intoString:nil]) {
			[result appendString:@"\f"];
		} else if ([scanner scanString:@"\\n" intoString:nil]) {
			[result appendString:@"\n"];
		} else if ([scanner scanString:@"\\r" intoString:nil]) {
			[result appendString:@"\r"];
		} else if ([scanner scanString:@"\\t" intoString:nil]) {
			[result appendString:@"\t"];
		} else if ([scanner scanString:@"\\/" intoString:nil]) {
			[result appendString:@"/"];
		} else if ([scanner scanString:@"\\\\" intoString:nil]) {
			[result appendString:@"\\"];
		} else if ([scanner scanCharactersFromSet:matchSet intoString:&value]) {
			// Didn't match any of the above patterns, so treat as normal text.
			[result appendString:value];
		}
	}
	
	return [NSString stringWithString:result];
}


@end
