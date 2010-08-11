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

- (void)loadHTMLString:(NSString *)string {
	// Use the app bundle as the base URL
	NSString *basePath = [[NSBundle mainBundle] resourcePath];
	NSURL *baseURL = [NSURL fileURLWithPath:basePath];
	
#ifdef TARGET_PROJECT_MAC
	// Load HTML into main frame
	WebFrame *webFrame = [self mainFrame];
	[webFrame loadHTMLString:string baseURL:baseURL];
#else
	[self loadHTMLString:string baseURL:baseURL];
#endif
}

- (NSString*) setDocumentElement:(NSString*)element visibility:(BOOL)visibility {
	NSString *value = visibility ? @"visible" : @"hidden";
	NSString *js = [NSString stringWithFormat: @"document.getElementById(\"%@\").style.visibility = \"%@\";", element, value];
	return [self stringByEvaluatingJavaScriptFromString:js];
}

- (NSString*) setDocumentElement:(NSString*)element innerHTML:(NSString*)html {
	// Create a javascript-safe string.
	NSMutableData *safeData = [NSMutableData dataWithCapacity:html.length * 2];
	int length = html.length;
	unichar c;
	BOOL inWhitespace = NO;
	const unichar kDoubleQuote = 0x0022;
	const unichar kBackslash = 0x005C;
	const unichar kSpace = 0x0020;
	
	for (int index = 0; index < length; index++) {
		c = [html characterAtIndex:index];
		switch (c) {
			case '\\': // Backslash
				[safeData appendBytes:&kBackslash length:2];
				[safeData appendBytes:&kBackslash length:2];
				inWhitespace = NO;
				break;
			case '\"': // Double-quotes
				[safeData appendBytes:&kBackslash length:2];
				[safeData appendBytes:&kDoubleQuote length:2];
				inWhitespace = NO;
				break;
			case 0: case '\t': case '\r': case '\n': // Whitespace to coalesce.
				if (inWhitespace == NO) {
					[safeData appendBytes:&kSpace length:2];
					inWhitespace = YES;
				}
				break;
			default:
				[safeData appendBytes:&c length:2];
				inWhitespace = NO;
				break;
		}
	}
	
	NSString *jsSafe = [NSString stringWithCharacters:safeData.bytes length:safeData.length / 2];
	
	// Set the inner HTML to the string.
	NSString *js = [NSString stringWithFormat: @"document.getElementById(\"%@\").innerHTML = \"%@\";", element, jsSafe];
	return [self stringByEvaluatingJavaScriptFromString:js];
}

- (void) scrollToTop {
	NSString *js = [NSString stringWithFormat: @"scroll(0,0);"];
	[self stringByEvaluatingJavaScriptFromString:js];
}

- (CGPoint) scrollPosition {
	NSString *jsResult;
	NSScanner *scanner;
	double x = -1.0;
	double y = -1.0;
	
	jsResult = [self stringByEvaluatingJavaScriptFromString:@"window.pageXOffset;"];
	if (jsResult.length > 0) {
		scanner = [NSScanner scannerWithString:jsResult];
		[scanner scanDouble: &x];
	}

	jsResult = [self stringByEvaluatingJavaScriptFromString:@"window.pageYOffset;"];
	if (jsResult.length > 0) {
		scanner = [NSScanner scannerWithString:jsResult];
		[scanner scanDouble: &y];
	}
	
	return CGPointMake (x, y);
}

@end
