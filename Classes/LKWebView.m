//
//  LKWebView.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "LKWebView.h"


@implementation LKWebView

- (NSString*) stringByEscapingQuotes:(NSString*)string {
	NSMutableString *result = [NSMutableString stringWithString: string];
	[result replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (NSString*) setDocumentElement:(NSString*)element visibility:(BOOL)visibility {
	NSString *value = visibility ? @"visible" : @"hidden";
	NSString *js = [NSString stringWithFormat: @"document.getElementById(\"%@\").style.visibility = \"%@\";", element, value];
	return [self stringByEvaluatingJavaScriptFromString:js];
}

- (NSString*) setDocumentElement:(NSString*)element innerHTML:(NSString*)html {
	NSString *escapedHtml = [self stringByEscapingQuotes: html];
	NSString *js = [NSString stringWithFormat: @"document.getElementById(\"%@\").innerHTML = \"%@\";", element, escapedHtml];
	return [self stringByEvaluatingJavaScriptFromString:js];
}

- (void) scrollToTop {
	NSString *js = [NSString stringWithFormat: @"scroll(0,0);"];
	[self stringByEvaluatingJavaScriptFromString:js];
}


@end
