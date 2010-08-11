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
@end

@implementation LKJSONParser
@synthesize keyPath, delegate;

- (id) initWithData:(NSData*)jsonData {
	if (self = [super init]) {
		jsonText = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
		scratchData = [[NSMutableData alloc] initWithCapacity:512];
	}
	return self;
}

- (void) dealloc {
	[jsonText release];
	[keyPath release];
	[scratchData release];
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
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
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
	[pool release];
}

- (NSString*) parseStringValue {
	// Skip the initial double-quote
	jsonOffset++;
	if (jsonOffset >= [jsonText length]) return nil;
	
	// Extract the value from the quoted string, substituting backslash escapes.
	unsigned int jsonLength = [jsonText length];
	[scratchData setLength:0];
	
	// Loop
	while (jsonOffset < jsonLength) {
		unichar c = [jsonText characterAtIndex:jsonOffset];
		jsonOffset++;
		if (c == '\"') {
			// Double-quote signifies the end of the string.
			break;
		} else if (c == '\\') { 
			// Backslash signifies an escaped char.
			c = [jsonText characterAtIndex:jsonOffset];
			jsonOffset++;
			
			switch (c) {
				case '\"': // Double-quote
					c = '\"';
					break;
				case '\\': // Backslash
					c = '\\';
					break;
				case 'b':
					c = '\b';
					break;
				case 'f':
					c = '\f';
					break;
				case 'n':
					c = '\n';
					break;
				case 'r':
					c = '\r';
					break;
				case 't':
					c = '\t';
					break;
				case '/':
					c = '/';
					break;
				case 'u':
					if (jsonOffset + 4 < jsonLength) {
						NSString *hexString = [jsonText substringWithRange: NSMakeRange(jsonOffset, 4)];
						NSScanner *hexScanner = [NSScanner scannerWithString:hexString];
						unsigned x = 0x20;
						if ([hexScanner scanHexInt:&x]) {
							c = x;
						}
						jsonOffset += 4;
					}
					break;
				default:
					break;
			}
			// Add the converted char.
			[scratchData appendBytes:&c length:sizeof(unichar)];
		} else { 
			// All other chars are passed through.
			[scratchData appendBytes:&c length:sizeof(unichar)];
		}
	}
	
	const unichar *resultChars = [scratchData mutableBytes];
	NSUInteger length = scratchData.length / sizeof(unichar);
	NSString *result = [NSString stringWithCharacters:resultChars length:length];
	return result;
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

@end
