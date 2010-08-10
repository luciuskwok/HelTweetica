//
//  NSString+HTMLFormatted.m
//  HelTweetica-Mac
//
//  Created by Lucius Kwok on 7/29/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "NSString+HTMLFormatted.h"

// Constants
#ifdef TARGET_PROJECT_MAC
const BOOL kConvertEmojiToImg = YES;
#else
const BOOL kConvertEmojiToImg = NO;
#endif

@implementation NSString (HTMLFormatted)

- (NSString *)stringWithLinksToURLsWithPrefix:(NSString *)prefix inString:(NSString *)string {
	static NSCharacterSet *nonURLSet = nil;
	if (nonURLSet == nil) {
		nonURLSet = [[NSCharacterSet characterSetWithCharactersInString:@" \t\r\n\"'"] retain];
	}
	
	NSMutableString *result = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:string];
	[scanner setCharactersToBeSkipped:nil];
	NSString *scanned;
	
	while ([scanner isAtEnd] == NO) {
		if ([scanner scanUpToString:prefix intoString:&scanned]) 
			[result appendString:scanned];
		if ([scanner scanUpToCharactersFromSet:nonURLSet intoString:&scanned]) {
			// Replace URLs with link text
			NSString *linkText = [scanned substringFromIndex: [scanned hasPrefix:@"https"] ? 8 : 7];
			if ([linkText length] > 29) {
				linkText = [NSString stringWithFormat: @"%@...", [linkText substringToIndex:26]];
			}
			[result appendFormat: @"<a href='%@'>%@</a>", scanned, linkText];
		}
	}
	return result;
}

- (NSString *)wordInString:(NSString *)string startingAtIndex:(unsigned int)index {
	if (index >= string.length) return nil;
	
	NSScanner *scanner = [NSScanner scannerWithString:[string substringFromIndex:index]];
	NSCharacterSet *wordSet = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789"];
	[scanner setCharactersToBeSkipped:nil];
	NSString *result = nil;
	if ([scanner scanCharactersFromSet:wordSet intoString:&result])
		return result;
	return nil;
}

- (NSString *)HTMLFormatted {
	
	// Add link tags to URLs
	NSString *string = [self stringWithLinksToURLsWithPrefix:@"http://" inString:self];
	string = [self stringWithLinksToURLsWithPrefix:@"https://" inString:string];
	
	// Move to a mutable string
	NSMutableString *result = [NSMutableString stringWithString:string];
	
	// Replace newlines and carriage returns with <br>
	[result replaceOccurrencesOfString:@"\r\n" withString:@"<br>" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\n" withString:@"<br>" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\r" withString:@"<br>" options:0 range:NSMakeRange(0, result.length)];
	
	// Replace tabs with a non-breaking space followed by a normal space
	[result replaceOccurrencesOfString:@"\t" withString:@"&nbsp; " options:0 range:NSMakeRange(0, result.length)];
	
	// Remove NULs
	[result replaceOccurrencesOfString:@"\0" withString:@"" options:0 range:NSMakeRange(0, result.length)];
	
	
	// Process letters outside of HTML tags. Break up long words with soft hyphens and detect @user strings.
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	unsigned int index = 0;
	unsigned int wordLength = 0;
	BOOL isInsideTag = NO;
	unichar c, previousChar = 0;
	while (index < result.length) {
		c = [result characterAtIndex:index];
		if (c == '<') {
			isInsideTag = YES;
		} else if (c == '>') {
			isInsideTag = NO;
			wordLength = 0;
		} else if (c == 160) { // non-breaking space
			wordLength++;
		} else if ([whitespace characterIsMember:c]) {
			wordLength = 0;
		} else {
			wordLength++;
		}
		
		if (isInsideTag == NO) {
			// Break up words longer than 13 chars
			if (wordLength >= 13) {
				[result replaceCharactersInRange:NSMakeRange(index, 0) withString:@"&shy;"]; // soft hyphen.
				index += 5;
				wordLength = 7; // Reset to 7 so that every 5 chars over 13, it gets a soft hyphen.
			}
			
			NSString *foundWord, *insertHTML;
			
			// @username: action link to User Page
			if (c == '@') {
				foundWord = [self wordInString:result startingAtIndex:index+1];
				if (foundWord.length > 0) {
					insertHTML = [NSString stringWithFormat: @"@<a href='action:user/%@'>%@</a>", foundWord, foundWord];
					[result replaceCharactersInRange: NSMakeRange(index, foundWord.length+1) withString: insertHTML];
					index += insertHTML.length - 1;
					wordLength = 0;
				}
			}
			
			// #hashtag: action link to Search
			if (c == '#' && previousChar != '&') {
				foundWord = [self wordInString:result startingAtIndex:index+1];
				if (foundWord.length > 0) {
					const int kMaxHashTagLength = 25;
					NSString *displayedHashTag = foundWord;
					if (displayedHashTag.length > kMaxHashTagLength)
						displayedHashTag = [[foundWord substringToIndex:kMaxHashTagLength] stringByAppendingString:@"..."];
					insertHTML = [NSString stringWithFormat: @"<a href='action:search/#%@'>#%@</a>", foundWord, displayedHashTag];
					[result replaceCharactersInRange: NSMakeRange(index, foundWord.length+1) withString: insertHTML];
					index += insertHTML.length - 1;
					wordLength = 0;
				}
			}
			
			// Emoji
			if (c >= 0xE00A && c <=  0xE537 && kConvertEmojiToImg) {
				NSString *insertHTML = [NSString stringWithFormat:@"<img class='emoji' src='emoji/kb-emoji-U+%X.png'>", c];
				[result replaceCharactersInRange:NSMakeRange(index, 1) withString:insertHTML];
				index += insertHTML.length - 1;
			}
		}
		
		previousChar = c;
		index++;
	}
	
	return result;
}

@end
