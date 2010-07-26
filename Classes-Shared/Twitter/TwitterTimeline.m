//
//  TwitterTimeline.m
//  HelTweetica
//
//  Created by Lucius Kwok on 5/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TwitterTimeline.h"
#import "TwitterStatusUpdate.h"
#import "TwitterLoadTimelineAction.h"


// Constants
enum { kMaxNumberOfMessagesInATimeline = 2000 };
// When reloading a timeline, newly downloaded messages are merged with existing ones, sorted by identifier, and the oldest ones past this limit are trimmed off.


@implementation TwitterTimeline
@synthesize messages, gaps, noOlderMessages, loadAction, defaultLoadCount, delegate;
//@synthesize twitter;

- (id)init {
	self = [super init];
	if (self) {
		self.messages = [NSMutableArray array];
		self.gaps = [NSMutableArray array];
		defaultLoadCount = 100;
	}
	return self;
}

- (void)dealloc {
	[messages release];
	[gaps release];
	[loadAction release];
	[super dealloc];
}

#pragma mark NSCoding

- (NSMutableArray*) mutableArrayForKey:(NSString *)key coder:(NSCoder *)decoder {
	NSData *data = [decoder decodeObjectForKey:key];
	NSMutableArray *array;
	if (data && [data isKindOfClass:[NSData class]]) {
		array = [NSMutableArray arrayWithArray: [NSKeyedUnarchiver unarchiveObjectWithData:data]];
	} else {
		array = [NSMutableArray array];
	}
	return array;
}

- (id) initWithCoder: (NSCoder*) decoder {
	if (self = [super init]) {
		self.messages = [self mutableArrayForKey:@"messages" coder:decoder];
		self.gaps = [self mutableArrayForKey:@"gaps" coder:decoder];
		defaultLoadCount = 50;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:messages] forKey: @"messages"];
	[encoder encodeObject: [NSKeyedArchiver archivedDataWithRootObject:gaps] forKey: @"gaps"];
}

#pragma mark Synchronize

- (TwitterStatusUpdate *)messageWithIdentifier:(NSNumber*)anIdentifier {
	TwitterStatusUpdate *message = nil;
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", anIdentifier];
	NSMutableArray *filteredArray = [NSMutableArray arrayWithArray: self.messages];
	[filteredArray filterUsingPredicate:predicate];
	if (filteredArray.count > 0)
		message = [filteredArray objectAtIndex:0];
	return message;
}

- (void)removeMessageWithIdentifier:(NSNumber*)anIdentifier {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", anIdentifier];
	NSMutableArray *filteredArray = [NSMutableArray arrayWithArray: self.messages];
	[filteredArray filterUsingPredicate:predicate];
	[self.messages removeObjectsInArray:filteredArray];
}

- (void)limitTimelineLength:(int)maxLength {
	// Limit the length of the timeline
	if (messages.count > maxLength) {
		NSRange removalRange = NSMakeRange(maxLength, messages.count - maxLength);
		[messages removeObjectsInRange:removalRange];
	}
}	

#pragma mark Loading

- (void)reloadNewer {
	TwitterLoadTimelineAction *action = self.loadAction;
	if (action == nil) return; // No action to reload.
	
	// Reset "since_id" and "max_id" parameters in case it was set from previous uses.
	[action.parameters removeObjectForKey:@"max_id"];
	[action.parameters removeObjectForKey:@"since_id"];
	
	if ([action.twitterMethod isEqualToString:@"favorites"] == NO) { // Only do this for non-Favorites timelines
		// Set the since_id parameter if there already are messages in the current timeline, except for the favorites timeline, because older tweets can be faved.
		NSNumber *newerThan = nil;
		
		// Skip past retweets because account user's own RTs don't show up in the home timeline.
		int messageIndex = 0;
		TwitterStatusUpdate *message;
		while (messageIndex < messages.count) {
			message = [messages objectAtIndex:messageIndex];
			messageIndex++;
			if (message.retweetedStatusIdentifier == nil) break;
		}
		// On exit, messageIndex points to the message one index after the first non-RT message.
		
		if (messageIndex < messages.count) {
			message = [messages objectAtIndex:messageIndex];
			newerThan = message.identifier;
		}
		
		if (newerThan)
			[action.parameters setObject:newerThan forKey:@"since_id"];
	}
	
	// Set the default load count
	[action.parameters setObject:[NSString stringWithFormat:@"%d", defaultLoadCount] forKey:@"count"];
	
	// Prepare action and start it. 
	action.timeline = self;
	action.completionTarget= self;
	action.completionAction = @selector(didReloadNewer:);
	[delegate startTwitterAction:action];
}

- (void)didReloadNewer:(TwitterLoadTimelineAction *)action {
	// Limit the length of the timeline
	[self limitTimelineLength:kMaxNumberOfMessagesInATimeline];
	
	// Also start an action to load RTs that the account's user has posted within the loaded timeline
	TwitterStatusUpdate *lastMessage = nil;
	if (action.loadedMessages.count > 1) {
		// If any messages were loaded, load RTs that would be mixed in with these tweets.
		lastMessage = [action.loadedMessages lastObject];
	} else if (action.timeline.messages.count > 0) {
		// If no messages were loaded, still load RTs since newest tweet.
		lastMessage = [action.timeline.messages objectAtIndex:0];
	}
	if (lastMessage) {
		NSNumber *sinceIdentifier = lastMessage.identifier;
		[self reloadRetweetsSince:sinceIdentifier toMax:nil];
	}
	
	// Call delegate so it can update the UI and Twitter cache.
	if ([delegate respondsToSelector:@selector(timeline:didLoadWithAction:)]) 
		[delegate timeline:self didLoadWithAction:action];
}

- (void)reloadRetweetsSince:(NSNumber*)sinceIdentifier toMax:(NSNumber*)maxIdentifier {
	// This only works for the user's own home timeline.
	if ([loadAction.twitterMethod isEqualToString:@"statuses/home_timeline"]) {
		TwitterLoadTimelineAction *action = [[[TwitterLoadTimelineAction alloc] initWithTwitterMethod:@"statuses/retweeted_by_me"] autorelease];
		if (sinceIdentifier) 
			[action.parameters setObject:sinceIdentifier forKey:@"since_id"];
		if (maxIdentifier) 
			[action.parameters setObject:maxIdentifier forKey:@"max_id"];
		[action.parameters setObject:[NSString stringWithFormat:@"%d", defaultLoadCount] forKey:@"count"];
		
		// Prepare action and start it. 
		action.timeline = self;
		action.completionTarget= self;
		action.completionAction = @selector(didReloadRetweets:);
		[delegate startTwitterAction:action];
	}
}

- (void)didReloadRetweets:(TwitterLoadTimelineAction *)action {
	// Remove the gap indicator for account user's own RTs.
	if (action.loadedMessages.count > 0) {
		[action.timeline.gaps removeObjectsInArray: action.loadedMessages];
	}
	
	// Call delegate so it can update the UI and Twitter cache.
	if ([delegate respondsToSelector:@selector(timeline:didLoadWithAction:)]) 
		[delegate timeline:self didLoadWithAction:action];
}

- (void)loadOlderWithMaxIdentifier:(NSNumber*)maxIdentifier {
	TwitterLoadTimelineAction *action = self.loadAction;
	if (action == nil) return; // No action to reload.
	
	if (maxIdentifier == nil && messages.count > 2) { // Load older
		TwitterStatusUpdate *message = [messages lastObject];
		maxIdentifier = message.identifier;
	}
	
	if (maxIdentifier)
		[action.parameters setObject:maxIdentifier forKey:@"max_id"];
	
	// Remove "since_id" parameter in case it was set from loading newer messages;
	[action.parameters removeObjectForKey:@"since_id"];
	
	// Prepare action and start it. 
	action.timeline = self;
	action.completionTarget= self;
	action.completionAction = @selector(didLoadOlderInCurrentTimeline:);
	[delegate startTwitterAction:action];
}

- (void) didLoadOlderInCurrentTimeline:(TwitterLoadTimelineAction *)action {
	if (action.newMessageCount <= 2) { // The one message is the one in the max_id.
		noOlderMessages = YES;
	}
	
	// TODO: load account user's own RTs within the range from max_id in the action to since_id of last tweet in action.messages.
	
	// Limit the length of the timeline
	[action.timeline limitTimelineLength:kMaxNumberOfMessagesInATimeline];
	
	// Call delegate so it can update the UI and Twitter cache.
	if ([delegate respondsToSelector:@selector(timeline:didLoadWithAction:)]) 
		[delegate timeline:self didLoadWithAction:action];
}


@end
