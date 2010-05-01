//
//  LKWebView.h
//  HelTweetica
//
//  Created by Lucius Kwok on 4/30/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface LKWebView : UIWebView {

}

- (NSString*) setDocumentElement:(NSString*)element visibility:(BOOL)visibility;
- (NSString*) setDocumentElement:(NSString*)element innerHTML:(NSString*)html;
- (void) scrollToTop;

@end
