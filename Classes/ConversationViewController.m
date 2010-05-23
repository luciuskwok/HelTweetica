    //
//  ConversationViewController.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/4/10.
/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ConversationViewController.h"
#import "ConversationHTMLController.h"


@implementation ConversationViewController


// Designated initializer. Uses aMessage as the head of a chain of replies, and gets each status in the reply chain.
- (id)initWithMessageIdentifier:(NSNumber*)anIdentifier {
	self = [super initWithNibName:@"Conversation" bundle:nil];
	if (self) {
		// Replace HTML controller with specific one for User Pages
		ConversationHTMLController *controller = [[[ConversationHTMLController alloc] initWithMessageIdentifier:anIdentifier] autorelease];
		controller.twitter = twitter;
		controller.delegate = self;
		[controller loadMessage:anIdentifier];
		self.timelineHTMLController = controller;
	}
	return self;
}

- (void) showConversationWithMessageIdentifier:(NSNumber*)identifier {
	// Select the tapped message
	ConversationHTMLController *controller= (ConversationHTMLController *)timelineHTMLController;
	controller.selectedMessageIdentifier = identifier;
	[controller rewriteTweetArea];
}


@end
