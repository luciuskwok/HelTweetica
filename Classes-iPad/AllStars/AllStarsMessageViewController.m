    //
//  AllStarsMessageViewController.m
//  HelTweetica
//
//  Created by Thomas Alvarez on 4/17/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "AllStarsMessageViewController.h"


@implementation AllStarsMessageViewController
@synthesize imageView, screenNameLabel, contentLabel, dateLabel;
@synthesize message, profileImage;

- (id)init {
    if ((self = [super initWithNibName:@"AllStarsMessageViewController" bundle:nil])) {
        // Custom initialization
		self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    }
    return self;
}

- (void)dealloc {
	[imageView release];
	[screenNameLabel release];
	[contentLabel release];
	[dateLabel release];
 	[message release];
	[profileImage release];
	[super dealloc];
}

#pragma mark -

- (NSString*) timeStringSinceNow: (NSDate*) date {
	if (date == nil) return nil;
	
	NSString *result = nil;
	NSTimeInterval timeSince = -[date timeIntervalSinceNow] / 60.0 ; // in minutes
	int value;
	NSString *units;
	if (timeSince <= 1.5) { // report in seconds
		value = floor (timeSince * 60.0);
		units = @"second";
	} else if (timeSince < 90.0) { // report in minutes
		value = floor (timeSince);
		units = @"minute";
	} else if (timeSince < 48.0 * 60.0) { // report in hours
		value = floor (timeSince / 60.0);
		units = @"hour";
	} else { // report in days
		value = floor (timeSince / (24.0 * 60.0));
		units = @"day";
	}
	if (value == 1) {
		result = [NSString stringWithFormat:@"1 %@ ago", units];
	} else {
		result = [NSString stringWithFormat:@"%d %@s ago", value, units];
	}
	return result;
}


- (void)viewDidLoad {
	[super viewDidLoad];
	
	NSMutableString *content = [NSMutableString stringWithString:message.content];
	[content replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, [content length])];
	[content replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, [content length])];
	[content replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, [content length])];
	
	[imageView setImage: profileImage];
	[screenNameLabel setText: message.userScreenName];
	[contentLabel setText: content];
	[dateLabel setText: [self timeStringSinceNow: message.createdDate]];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


- (void)viewDidUnload {
	[super viewDidUnload];
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.imageView = nil;
	self.screenNameLabel = nil;
	self.contentLabel = nil;
	self.dateLabel = nil;
}



#pragma mark -

- (IBAction) close: (id) sender {
	[self dismissModalViewControllerAnimated:YES];
}

@end
