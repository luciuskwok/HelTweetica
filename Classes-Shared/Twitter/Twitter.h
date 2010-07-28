//
//  Twitter.h
//  HelTweetica
//
//  Created by Lucius Kwok on 3/30/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>

#import <sqlite3.h>
#import "LKSqliteDatabase.h"

#import "TwitterAccount.h"
#import "TwitterUser.h"
#import "TwitterStatusUpdate.h"
#import "TwitterDirectMessage.h"


@protocol TwitterDelegate;

@interface Twitter : NSObject {
	NSMutableArray *accounts;
	LKSqliteDatabase *database;
}

@property (nonatomic, retain) NSMutableArray *accounts;
@property (nonatomic, retain) LKSqliteDatabase *database;

- (TwitterAccount*) accountWithScreenName: (NSString*) screenName;
- (void) moveAccountAtIndex:(int)fromIndex toIndex:(int)toIndex;

// Status Updates
- (void)addStatusUpdates:(NSArray *)newUpdates;
- (TwitterStatusUpdate *)statusUpdateWithIdentifier:(NSNumber *)identifier;
- (NSSet*) statusUpdatesInReplyToStatusIdentifier:(NSNumber*)identifier;

// Direct Messages
- (void)addDirectMessages:(NSArray *)newMessages;
- (TwitterDirectMessage *)directMessageWithIdentifier:(NSNumber *)identifier;

// Users
- (void)addUsers:(NSSet *)newUsers; // Add users if not already in database.
- (void)addOrReplaceUsers:(NSSet *)newUsers; // Add users replacing existing users in database.
- (TwitterUser *)userWithScreenName:(NSString *)screenName;
- (TwitterUser *)userWithIdentifier:(NSNumber *)identifier;
- (NSArray *)allUsers;
- (NSArray *)usersWithName:(NSString *)name;

- (void)saveUserDefaults;

@end
