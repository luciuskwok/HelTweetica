//
//  LKWebView.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/30/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "LKWebView.h"


@implementation LKWebView

- (NSString*) javascriptSafeString:(NSString*)string {
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
	NSString *value;
	NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"\0\t\r\n\"\\"];
	NSCharacterSet *skipSet = [NSCharacterSet characterSetWithCharactersInString:@"\0\t\r\n"];
	
	[scanner setCharactersToBeSkipped:nil];
	
	while ([scanner isAtEnd] == NO) {
		if ([scanner scanUpToCharactersFromSet:set intoString:&value]) {
			[result appendString: value];
		}
		if ([scanner scanString:@"\\" intoString:nil]) {
			[result appendString:@"\\\\"];
		} else if ([scanner scanString:@"\"" intoString:nil]) {
			[result appendString:@"\\\""];
		} else {
			[scanner scanCharactersFromSet:skipSet intoString:nil];
			[result appendString:@" "];
		}
	}
	
	return result;
}

- (NSString*) setDocumentElement:(NSString*)element visibility:(BOOL)visibility {
	NSString *value = visibility ? @"visible" : @"hidden";
	NSString *js = [NSString stringWithFormat: @"document.getElementById(\"%@\").style.visibility = \"%@\";", element, value];
	return [self stringByEvaluatingJavaScriptFromString:js];
}

- (NSString*) setDocumentElement:(NSString*)element innerHTML:(NSString*)html {
	NSString *escapedHtml = [self javascriptSafeString: html];
	NSString *js = [NSString stringWithFormat: @"document.getElementById(\"%@\").innerHTML = \"%@\";", element, escapedHtml];
	return [self stringByEvaluatingJavaScriptFromString:js];
}

- (void) scrollToTop {
	NSString *js = [NSString stringWithFormat: @"scroll(0,0);"];
	[self stringByEvaluatingJavaScriptFromString:js];
}

- (CGPoint) scrollPosition {
	CGPoint position = CGPointMake(-1, -1);
	NSString *jsResult;
	NSScanner *scanner;
	
	jsResult = [self stringByEvaluatingJavaScriptFromString:@"window.pageXOffset;"];
	if (jsResult.length > 0) {
		scanner = [NSScanner scannerWithString:jsResult];
		[scanner scanFloat:&position.x];
	}

	jsResult = [self stringByEvaluatingJavaScriptFromString:@"window.pageYOffset;"];
	if (jsResult.length > 0) {
		scanner = [NSScanner scannerWithString:jsResult];
		[scanner scanFloat:&position.y];
	}
	
	return position;
}

@end
