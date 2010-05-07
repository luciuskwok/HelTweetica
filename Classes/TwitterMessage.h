//
//  Message.h
//  HelTweetica
//
//  Created by Lucius Kwok on 4/1/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface TwitterMessage : NSObject {
	NSNumber *identifier;
	NSNumber *inReplyToStatusIdentifier;
	NSNumber *inReplyToUserIdentifier;
	
	NSString *screenName;
	NSString *inReplyToScreenName;
	NSString *avatar;
	NSString *content;
	NSString *source;
	TwitterMessage *retweetedMessage;
	
	NSDate *createdDate;
	NSDate *receivedDate;
	
	UIImage *largeAvatar;
	
	BOOL locked;
	BOOL favorite;
	BOOL direct;
	
	NSURLConnection *downloadConnection;
	NSInteger downloadStatusCode;
	NSMutableData *downloadData;
	BOOL isLoading;
	
}
@property (nonatomic, retain) NSNumber *identifier;
@property (nonatomic, retain) NSNumber *inReplyToStatusIdentifier;
@property (nonatomic, retain) NSNumber *inReplyToUserIdentifier;

@property (nonatomic, retain) NSString *screenName;
@property (nonatomic, retain) NSString *inReplyToScreenName;
@property (nonatomic, retain) NSString *avatar;
@property (nonatomic, retain) NSString *content;
@property (nonatomic, retain) NSString *source;
@property (nonatomic, retain) TwitterMessage *retweetedMessage;

@property (nonatomic, retain) NSDate *createdDate;
@property (nonatomic, retain) NSDate *receivedDate;

@property (nonatomic, retain) UIImage *largeAvatar;

@property (assign, getter=isLocked) BOOL locked;
@property (assign, getter=isFavorite) BOOL favorite;
@property (assign, getter=isDirect) BOOL direct;

@property (nonatomic, retain) NSURLConnection *downloadConnection;
@property (nonatomic, retain) NSMutableData *downloadData;

- (SInt64) identifierInt64;
- (void) setIdentifierInt64:(SInt64)x;

- (void) loadLargeAvatar;

- (void) setValue:(id)value forTwitterKey:(NSString*)key;


@end
